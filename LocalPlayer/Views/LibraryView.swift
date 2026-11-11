import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 长按锚点

private struct CardTarget: Equatable {
    let item: VideoItem
    let rect: CGRect
}

private struct FolderTarget: Equatable {
    let path: String
    let rect: CGRect
}

private enum LibraryPopup: Equatable {
    case importing
    case more
}

private struct CardFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct FolderFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - 资料库

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: AppSettings

    @State private var playingItem: VideoItem?
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var showSettings = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    @State private var popup: LibraryPopup?
    @State private var target: CardTarget?
    @State private var folderTarget: FolderTarget?
    /// 长按刚触发时，同一串手势不要再被当成「点空白关闭」
    @State private var menuGuard = Date.distantPast
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var folderFrames: [String: CGRect] = [:]
    /// 刷新缩略图时递增，用来强制 LazyVGrid 重建、重新生成缩略图
    @State private var refreshToken = 0

    @State private var renaming: VideoItem?
    @State private var renameText = ""
    @State private var deleting: VideoItem?

    @State private var renamingFolder: String?
    @State private var folderRenameText = ""
    @State private var deletingFolder: String?
    @State private var movingItem: VideoItem?

    @State private var toastText: String?
    @State private var toastToken = 0
    @State private var isImporting = false

    private let sidePadding: CGFloat = 16
    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Palette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    if library.currentFolder != nil { breadcrumb }
                    content
                }

                if popup != nil || target != nil || folderTarget != nil {
                    scrim
                }

                if let target {
                    floatingCard(target)
                    cardMenu(target, screen: proxy.size)
                }

                if let folderTarget {
                    floatingFolder(folderTarget)
                    folderMenu(folderTarget, screen: proxy.size)
                }

                if let currentPopup = popup {
                    switch currentPopup {
                    case .importing:
                        ImportMenu(
                            onPhoto: { popup = nil; showPhotoPicker = true },
                            onFile: { popup = nil; showFileImporter = true }
                        )
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, sidePadding)
                        .transition(.opacity)

                    case .more:
                        MoreMenu(
                            sortKey: settings.sortKey,
                            ascending: settings.sortAscending,
                            onNewFolder: { popup = nil; newFolderName = ""; showNewFolder = true },
                            onSort: { key in
                                settings.sortKey = key
                                settings.sortAscending = true
                            },
                            onToggleOrder: { settings.sortAscending.toggle() },
                            onRefresh: {
                                popup = nil
                                ThumbnailLoader.shared.clear()
                                library.reload()
                                refreshToken += 1
                                toast("已刷新缩略图")
                            }
                        )
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, sidePadding)
                        .transition(.opacity)
                    }
                }

                toastView
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .coordinateSpace(name: "root")
            .animation(.easeOut(duration: 0.16), value: popup)
            .animation(.easeOut(duration: 0.16), value: target)
            .animation(.easeOut(duration: 0.16), value: folderTarget)
        }
        .overlay { importingOverlay }
        .onAppear {
            library.reload()
            progress.refresh()
            applyDebugRoute()
        }
        .onChange(of: photoSelections) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoSelections,
            maxSelectionCount: 20,
            matching: .videos
        )
        .fullScreenCover(item: $playingItem) { item in
            PlayerScreen(item: item, queue: sortedVideos)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("取消", role: .cancel) { newFolderName = "" }
            Button("创建") {
                library.createFolder(newFolderName)
                newFolderName = ""
                toast("已创建文件夹")
            }
        }
        .alert("重命名", isPresented: renameBinding) {
            TextField("文件名", text: $renameText)
            Button("取消", role: .cancel) { renaming = nil }
            Button("保存") { commitRename() }
        } message: {
            Text("会同时改磁盘上的文件名，扩展名保留")
        }
        .alert(
            "删除「\(deleting?.displayName ?? "")」？",
            isPresented: deleteBinding,
            presenting: deleting
        ) { item in
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                progress.forget(id: item.id)
                library.delete(item)
                deleting = nil
                toast("已删除")
            }
        } message: { _ in
            Text("文件会从本机移除，这个操作不能撤销。")
        }
        .alert("重命名文件夹", isPresented: folderRenameBinding) {
            TextField("显示名称", text: $folderRenameText)
            Button("取消", role: .cancel) { renamingFolder = nil }
            Button("保存") { commitFolderRename() }
        } message: {
            Text("只改显示名，磁盘上的目录名不变，里面的视频不受影响。")
        }
        .alert(
            "删除文件夹「\(deletingFolderName)」？",
            isPresented: folderDeleteBinding,
            presenting: deletingFolder
        ) { path in
            Button("取消", role: .cancel) { deletingFolder = nil }
            Button("删除", role: .destructive) { deleteSelectedFolder(path) }
        } message: { path in
            Text("文件夹里的 \(library.itemsInside(path).count) 个视频会一起从本机移除，这个操作不能撤销。")
        }
        .sheet(item: $movingItem) { item in
            MoveFolderSheet(item: item, choices: library.folderChoices) { path in
                moveItem(item, to: path)
            }
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 8) {
            GlassIconButton(systemName: "gearshape", size: 36, iconSize: 17) {
                showSettings = true
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            GlassIconButton(systemName: "square.and.arrow.down", size: 36, iconSize: 17) {
                popup = popup == .importing ? nil : .importing
            }
            GlassIconButton(systemName: "ellipsis", size: 36, iconSize: 17) {
                popup = popup == .more ? nil : .more
            }
        }
        .padding(.horizontal, sidePadding)
        .frame(height: 54)
    }

    private var title: String {
        guard let folder = library.currentFolder else { return "资料库" }
        return library.displayName(forFolder: folder)
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Button {
                library.currentFolder = nil
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("资料库")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 8)
    }

    // MARK: - 网格

    private var content: some View {
        ScrollView {
            if library.subfolders.isEmpty && sortedVideos.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: columnSpacing),
                        GridItem(.flexible(), spacing: columnSpacing)
                    ],
                    alignment: .leading,
                    spacing: rowSpacing
                ) {
                    ForEach(library.subfolders, id: \.self) { folder in
                        FolderCard(
                            name: library.displayName(forFolder: folder),
                            count: count(in: folder)
                        )
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: FolderFrameKey.self,
                                    value: [folder: geo.frame(in: .named("root"))]
                                )
                            }
                        }
                        .onTapGesture {
                            if folderTarget != nil || target != nil {
                                if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
                            } else {
                                library.currentFolder = folder
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.38) {
                            openFolderMenu(folder)
                        }
                    }

                    ForEach(sortedVideos) { item in
                        card(item)
                    }
                }
                .id(refreshToken)
                .padding(.horizontal, sidePadding)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
        .onPreferenceChange(FolderFrameKey.self) { folderFrames = $0 }
    }

    private func card(_ item: VideoItem) -> some View {
        VideoCard(
            item: item,
            fraction: progress.progressFraction(for: item.id),
            watched: progress.isWatched(item.id),
            active: target?.item.id == item.id
        )
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardFrameKey.self,
                    value: [item.id: geo.frame(in: .named("root"))]
                )
            }
        }
        .onTapGesture {
            if target != nil || folderTarget != nil {
                if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
            } else {
                playingItem = item
            }
        }
        .onLongPressGesture(minimumDuration: 0.38) {
            openCardMenu(item)
        }
    }

    private func count(in folder: String) -> Int {
        library.allItems.filter { $0.folder == folder || $0.folder.hasPrefix(folder + "/") }.count
    }

    /// 文件夹排在前面，视频按当前排序规则
    private var sortedVideos: [VideoItem] {
        let list = library.items
        let key = settings.sortKey
        let asc = settings.sortAscending

        return list.sorted { a, b in
            let forward: Bool
            switch key {
            case .recent:
                let ra = progress.recencyRank(a.id)
                let rb = progress.recencyRank(b.id)
                if ra != rb {
                    forward = ra < rb
                } else {
                    forward = a.modified > b.modified
                }
            case .name:
                forward = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .added:
                forward = a.modified > b.modified
            case .size:
                if a.fileSize != b.fileSize {
                    forward = a.fileSize < b.fileSize
                } else {
                    forward = a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
            return asc ? forward : !forward
        }
    }

    // MARK: - 长按菜单

    private var scrim: some View {
        Color.black.opacity(0.38)
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture {
                guard Date().timeIntervalSince(menuGuard) > 0.35 else { return }
                closeMenus()
                popup = nil
            }
    }

    /// 被长按的卡片浮在遮罩之上，保持清晰
    private func floatingCard(_ target: CardTarget) -> some View {
        VideoCard(
            item: target.item,
            fraction: progress.progressFraction(for: target.item.id),
            watched: progress.isWatched(target.item.id),
            active: true
        )
        .frame(width: target.rect.width, alignment: .top)
        .position(x: target.rect.midX, y: target.rect.midY)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func floatingFolder(_ target: FolderTarget) -> some View {
        FolderCard(
            name: library.displayName(forFolder: target.path),
            count: count(in: target.path)
        )
        .frame(width: target.rect.width, alignment: .top)
        .position(x: target.rect.midX, y: target.rect.midY)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func cardMenu(_ target: CardTarget, screen: CGSize) -> some View {
        let width = CardMenu.width
        let height = CardMenu.estimatedHeight
        let x = min(max(sidePadding, target.rect.minX), max(sidePadding, screen.width - sidePadding - width))
        var y = target.rect.maxY + 8
        if y + height > screen.height - 16 {
            y = target.rect.minY - height - 8
        }
        y = max(16, y)

        return CardMenu(
            item: target.item,
            watched: progress.isWatched(target.item.id),
            onMarkWatched: {
                progress.setWatched(target.item.id, !progress.isWatched(target.item.id))
                closeCardMenu()
            },
            onRename: {
                renameText = target.item.displayName
                renaming = target.item
                closeCardMenu()
            },
            onMove: {
                movingItem = target.item
                closeCardMenu()
            },
            onDelete: {
                deleting = target.item
                closeCardMenu()
            }
        )
        .position(x: x + width / 2, y: y + height / 2)
        .transition(.opacity)
    }

    private func folderMenu(_ target: FolderTarget, screen: CGSize) -> some View {
        let width = FolderMenu.width
        let height = FolderMenu.estimatedHeight
        let x = min(max(sidePadding, target.rect.minX), max(sidePadding, screen.width - sidePadding - width))
        var y = target.rect.maxY + 8
        if y + height > screen.height - 16 {
            y = target.rect.minY - height - 8
        }
        y = max(16, y)

        return FolderMenu(
            name: library.displayName(forFolder: target.path),
            onRename: {
                folderRenameText = library.displayName(forFolder: target.path)
                renamingFolder = target.path
                closeMenus()
            },
            onDelete: {
                deletingFolder = target.path
                closeMenus()
            }
        )
        .position(x: x + width / 2, y: y + height / 2)
        .transition(.opacity)
    }

    private func openCardMenu(_ item: VideoItem) {
        popup = nil
        folderTarget = nil
        menuGuard = Date()
        let rect = cardFrames[item.id] ?? .zero
        withAnimation(.easeOut(duration: 0.16)) {
            target = CardTarget(item: item, rect: rect)
        }
    }

    private func openFolderMenu(_ path: String) {
        popup = nil
        target = nil
        menuGuard = Date()
        let rect = folderFrames[path] ?? .zero
        withAnimation(.easeOut(duration: 0.16)) {
            folderTarget = FolderTarget(path: path, rect: rect)
        }
    }

    private func closeCardMenu() {
        withAnimation(.easeOut(duration: 0.16)) { target = nil }
    }

    private func closeMenus() {
        withAnimation(.easeOut(duration: 0.16)) {
            target = nil
            folderTarget = nil
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Palette.tertiaryText)

            Text("还没有视频")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.text)

            Text("从相册或「文件」App 导入\n视频只存在本机，不联网、不上传")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(Palette.tertiaryText)

            HStack(spacing: 8) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showFileImporter = true
                } label: {
                    Label("文件", systemImage: "folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .glass(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .glass(cornerRadius: 18)
        .padding(.horizontal, sidePadding)
        .padding(.top, 40)
    }

    // MARK: - 浮层

    @ViewBuilder
    private var toastView: some View {
        if let toastText {
            Text(toastText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glass(Capsule())
                .padding(.bottom, 28)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var importingOverlay: some View {
        if isImporting {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("正在从相册导入…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .glass(cornerRadius: 14)
            }
        }
    }

    // MARK: - 绑定

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )
    }

    private var folderRenameBinding: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )
    }

    private var folderDeleteBinding: Binding<Bool> {
        Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )
    }

    private var deletingFolderName: String {
        guard let path = deletingFolder else { return "" }
        return library.displayName(forFolder: path)
    }

    // MARK: - 动作

    private func commitRename() {
        guard let item = renaming else { return }
        let oldID = item.id
        renaming = nil
        guard let renamed = library.rename(item, to: renameText) else {
            toast("重命名失败，可能有同名文件")
            return
        }
        progress.renamePath(from: oldID, to: renamed.id)
        toast("已重命名")
    }

    private func commitFolderRename() {
        guard let path = renamingFolder else { return }
        renamingFolder = nil
        library.renameFolder(path, to: folderRenameText)
        toast("已重命名")
    }

    private func deleteSelectedFolder(_ path: String) {
        let victims = library.itemsInside(path)
        for item in victims { progress.forget(id: item.id) }
        let removed = library.deleteFolder(path)
        if library.currentFolder == path { library.currentFolder = nil }
        deletingFolder = nil
        toast(removed > 0 ? "已删除文件夹（含 \(removed) 个视频）" : "已删除空文件夹")
    }

    private func moveItem(_ item: VideoItem, to path: String) {
        guard path != item.folder else { return }
        let oldID = item.id
        guard let moved = library.move(item, to: path) else {
            toast("移动失败，目标里可能有同名文件")
            return
        }
        progress.renamePath(from: oldID, to: moved.id)
        let name = path.isEmpty ? "资料库" : library.displayName(forFolder: path)
        toast("已移到「\(name)」")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let count = library.importURLs(urls)
            toast(count > 0 ? "已导入 \(count) 个文件" : "没有导入成功")
        case .failure:
            toast("导入失败")
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        isImporting = true
        let folder = library.currentFolder
        Task {
            let count = await PhotoImporter.importItems(items, into: folder, library: library)
            await MainActor.run {
                isImporting = false
                photoSelections = []
                toast(count > 0 ? "已从相册导入 \(count) 个视频" : "没有导入成功")
            }
        }
    }

    private func toast(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(.easeOut(duration: 0.15)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastToken == token {
                withAnimation(.easeIn(duration: 0.2)) { toastText = nil }
            }
        }
    }

    // MARK: - 调试直达

    private func applyDebugRoute() {
        #if DEBUG
        guard let route = DebugSeed.argument(after: "-screen") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            switch route {
            case "player":
                if let first = library.allItems.first {
                    if !first.folder.isEmpty { library.currentFolder = first.folder }
                    playingItem = first
                }
            case "folder":
                if let first = library.subfolders.first { library.currentFolder = first }
            case "settings":
                showSettings = true
            case "foldermenu":
                // 等卡片布局完成、folderFrames 有值之后再弹菜单，否则锚点是 .zero
                if let first = library.subfolders.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openFolderMenu(first)
                    }
                }
            case "move":
                if let first = library.allItems.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        movingItem = first
                    }
                }
            default:
                break
            }
        }
        #endif
    }
}
