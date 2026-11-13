import Foundation
import Combine

/// 「移到文件夹」弹窗里的一个候选目录
struct FolderChoice: Identifiable, Hashable {
    let path: String
    let display: String
    let depth: Int

    var id: String { path }
}

final class LibraryStore: ObservableObject {
    @Published private(set) var allItems: [VideoItem] = []
    @Published private(set) var folders: [String] = []
    /// nil 表示根目录
    @Published var currentFolder: String?
    @Published private(set) var totalSize: Int64 = 0
    /// 正在导入的进度；nil 表示没有在导入
    @Published private(set) var importProgress: ImportProgress?

    let documents: URL

    /// 监听 Documents 目录本身的变化：爱思助手、文件 App、iCloud 从外部写进来的文件
    /// 不会触发任何 SwiftUI 回调，只能靠文件系统事件兜住。
    private var watcher: DispatchSourceFileSystemObject?
    private var reloadWorkItem: DispatchWorkItem?

    init() {
        documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadFolderNames()
        reload()
        startWatching()
    }

    deinit {
        watcher?.cancel()
        reloadWorkItem?.cancel()
    }

    // MARK: - 目录监听

    private func startWatching() {
        let fd = open(documents.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    /// 批量导入会连着触发好多次事件，攒 0.4 秒只刷一次
    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - 扫描

    func reload() {
        let fm = FileManager.default
        var items: [VideoItem] = []
        var folderSet = Set<String>()

        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        let enumerator = fm.enumerator(
            at: documents,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let url = enumerator?.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                // 同样走 relativePath，避免 /private 前缀导致子目录也算错
                if let relative = VideoItem.relativePath(of: url, in: documents),
                   !relative.isEmpty,
                   !relative.hasPrefix(".") {
                    folderSet.insert(relative)
                }
                continue
            }
            if values?.isHidden == true { continue }
            if let item = VideoItem(url: url, documents: documents) {
                items.append(item)
            }
        }

        items.sort { $0.modified > $1.modified }
        allItems = items
        folders = folderSet.sorted()
        totalSize = items.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 派生数据

    /// 当前目录下的视频（未排序，排序交给视图，因为「最近播放」需要 ProgressStore）
    var items: [VideoItem] {
        let folder = currentFolder ?? ""
        return allItems.filter { $0.folder == folder }
    }

    /// 当前目录下的直接子文件夹
    var subfolders: [String] {
        let parent = currentFolder ?? ""
        return folders.filter { path in
            (path as NSString).deletingLastPathComponent == parent
        }
    }

    var isEmpty: Bool { allItems.isEmpty && folders.isEmpty }

    // MARK: - 导入 / 删除

    /// 逐个搬进当前目录，每搬完一个更新一次进度。
    ///
    /// 真正的文件 I/O 在 `ImportService` 的 detached task 里跑，这里只在主线程
    /// 收结果、推进度（`@Published` 必须回到主 actor 才能改）。
    /// 之前 `copyItem` 是同步执行的，大文件会冻界面。
    @MainActor
    func importItems(_ items: [ImportItem]) async -> ImportResult {
        guard !items.isEmpty else { return ImportResult() }

        let target = currentFolder.map { documents.appendingPathComponent($0, isDirectory: true) } ?? documents
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        var result = ImportResult()
        result.total = items.count
        importProgress = ImportProgress(done: 0, total: items.count)

        for (index, item) in items.enumerated() {
            let one = await ImportService.bring(item, into: target)
            result.copied += one.copied
            result.renamed += one.renamed
            result.failed += one.failed
            importProgress = ImportProgress(done: index + 1, total: items.count)
        }

        importProgress = nil
        if result.copied > 0 { reload() }
        return result
    }

    func delete(_ item: VideoItem) {
        try? FileManager.default.removeItem(at: item.url)
        reload()
    }

    /// 批量删除：一次 reload，避免多选时反复扫盘
    @discardableResult
    func deleteMany(ids: Set<String>) -> Int {
        var removed = 0
        for item in allItems where ids.contains(item.id) {
            if (try? FileManager.default.removeItem(at: item.url)) != nil { removed += 1 }
        }
        if removed > 0 { reload() }
        return removed
    }

    /// 真的改磁盘上的文件名（扩展名保留）。成功返回重命名后的条目，失败返回 nil。
    func rename(_ item: VideoItem, to newBase: String) -> VideoItem? {
        let trimmed = newBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let ext = item.ext
        let target = item.url
            .deletingLastPathComponent()
            .appendingPathComponent(trimmed)
            .appendingPathExtension(ext)
        if target.path == item.url.path { return item }

        do {
            try FileManager.default.moveItem(at: item.url, to: target)
        } catch {
            return nil
        }

        reload()
        let relative = VideoItem.relativePath(of: target, in: documents) ?? target.lastPathComponent
        return VideoItem(url: target, documents: documents) ?? allItems.first { $0.relativePath == relative }
    }

    func createFolder(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let base = currentFolder.map { documents.appendingPathComponent($0) } ?? documents
        let target = base.appendingPathComponent(trimmed)
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - 文件夹：显示名 / 删除 / 移动

    private let folderNamesKey = "folder.displayNames.v1"

    /// 相对路径 → 自定义显示名。**只影响界面，磁盘目录名始终不变**，
    /// 所以里面视频的 id（相对路径）和进度记录都不受影响。
    @Published private(set) var folderNames: [String: String] = [:]

    func displayName(forFolder path: String) -> String {
        if let custom = folderNames[path], !custom.isEmpty { return custom }
        return (path as NSString).lastPathComponent
    }

    func renameFolder(_ path: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !trimmed.isEmpty else { return }
        if (path as NSString).lastPathComponent == trimmed {
            folderNames.removeValue(forKey: path)
        } else {
            folderNames[path] = trimmed
        }
        saveFolderNames()
        objectWillChange.send()
    }

    /// 递归删除整个文件夹，返回被删掉的视频数量
    @discardableResult
    func deleteFolder(_ path: String) -> Int {
        guard !path.isEmpty else { return 0 }
        let target = documents.appendingPathComponent(path, isDirectory: true)
        let removed = itemsInside(path).count
        try? FileManager.default.removeItem(at: target)
        folderNames = folderNames.filter { key, _ in
            key != path && !key.hasPrefix(path + "/")
        }
        saveFolderNames()
        reload()
        return removed
    }

    /// 某个文件夹（含子目录）里的所有视频
    func itemsInside(_ folder: String) -> [VideoItem] {
        allItems.filter { $0.folder == folder || $0.folder.hasPrefix(folder + "/") }
    }

    /// 把视频移到另一个文件夹（"" 表示根目录）。成功返回移动后的条目。
    func move(_ item: VideoItem, to folder: String) -> VideoItem? {
        guard item.folder != folder else { return item }
        let destination = folder.isEmpty
            ? documents
            : documents.appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let target = FileManager.default.uniqueURL(in: destination, preferredName: item.name)
        do {
            try FileManager.default.moveItem(at: item.url, to: target)
        } catch {
            return nil
        }
        reload()
        return VideoItem(url: target, documents: documents)
    }

    /// 移动弹窗用的目标列表：根目录在最前，其余按路径排序
    var folderChoices: [FolderChoice] {
        var result: [FolderChoice] = [
            FolderChoice(path: "", display: "资料库（根目录）", depth: 0)
        ]
        for path in folders {
            let depth = path.components(separatedBy: "/").count - 1
            result.append(
                FolderChoice(path: path, display: displayName(forFolder: path), depth: depth)
            )
        }
        return result
    }

    private func loadFolderNames() {
        folderNames = UserDefaults.standard.dictionary(forKey: folderNamesKey) as? [String: String] ?? [:]
    }

    private func saveFolderNames() {
        UserDefaults.standard.set(folderNames, forKey: folderNamesKey)
    }
}
