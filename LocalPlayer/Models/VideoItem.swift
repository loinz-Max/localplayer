import Foundation

struct VideoItem: Identifiable, Hashable {
    let url: URL
    /// 相对 Documents 的路径，同时作为稳定 ID（用于记录播放进度）
    let relativePath: String
    let name: String
    /// 相对文件夹路径，根目录为空字符串
    let folder: String
    let fileSize: Int64
    let modified: Date
    let ext: String

    var id: String { relativePath }

    var displayName: String { (name as NSString).deletingPathExtension }

    /// 系统原生解码（AVPlayer）能直接播的容器。
    /// 不放 ts / m2ts：AVPlayer 只在 HLS 分片里认 MPEG-TS，独立的 .ts 文件经常直接失败，
    /// 放进来会让界面显示「可播」但点开报错。它们仍会出现在列表里（带警告图标）。
    static let systemExtensions: Set<String> = [
        "mp4", "mov", "m4v", "3gp", "mpg", "mpeg"
    ]

    /// 列表里愿意展示的所有视频扩展名
    static let videoExtensions: Set<String> = systemExtensions.union([
        "mkv", "avi", "wmv", "flv", "webm", "rmvb", "rm", "ogv", "vob", "asf", "divx", "mts", "m2ts", "ts"
    ])

    var systemPlayable: Bool {
        VideoItem.systemExtensions.contains(ext)
    }
}

extension VideoItem {
    init?(url: URL, documents: URL) {
        let ext = url.pathExtension.lowercased()
        guard VideoItem.videoExtensions.contains(ext) else { return nil }

        let relative = VideoItem.relativePath(of: url, in: documents) ?? url.lastPathComponent
        let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attrs[.modificationDate] as? Date) ?? Date.distantPast
        let folder = (relative as NSString).deletingLastPathComponent

        self.url = url
        self.relativePath = relative
        self.name = url.lastPathComponent
        self.folder = folder
        self.fileSize = size
        self.modified = modified
        self.ext = ext
    }

    /// 取相对 Documents 的路径。
    ///
    /// 不能直接对绝对路径做字符串替换：外部进程（爱思助手 / 文件 App / AFC 拷贝）写进来的文件，
    /// 路径可能是 `/private/var/mobile/.../Documents/x.mp4`，而 `urls(for: .documentDirectory)`
    /// 给的是 `/var/mobile/.../Documents`。替换失败时相对路径就成了整条绝对路径，
    /// `folder` 随之变成「绝对路径的父目录」，于是这些视频在根目录里永远筛不出来
    /// —— 表现就是「设置里数得到、列表里看不到」。
    static func relativePath(of url: URL, in root: URL) -> String? {
        let prefixes = [root.path, "/private" + root.path]
        for prefix in prefixes where url.path.hasPrefix(prefix + "/") {
            return String(url.path.dropFirst(prefix.count + 1))
        }
        return nil
    }
}

/// 排序依据：⋯ 菜单里的二选一（名称 / 日期）。
/// 菜单文案写在 `MoreMenu` 里（带 ↑↓），所以这里不需要 title；
/// 旧数据可能存着已移除的 recent / size，解码失败时回落到名称。
enum SortKey: String {
    case name, added
}

/// 播放模式：单集循环 / 列表循环 / 播完暂停
enum PlayMode: String, CaseIterable, Identifiable {
    case loopAll, loopOne, stopAtEnd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loopAll: return "列表循环"
        case .loopOne: return "单集循环"
        case .stopAtEnd: return "播完暂停"
        }
    }

}
