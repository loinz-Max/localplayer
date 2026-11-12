import Foundation

/// 一次导入的进度：总共几个、搬完几个
struct ImportProgress: Equatable, Sendable {
    var done: Int
    var total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(done) / Double(total)))
    }
}

/// 导入结果。同名文件会被自动改成「名字 2」，单独计数，好在提示里说清楚。
struct ImportResult: Equatable, Sendable {
    var total = 0
    var copied = 0
    var renamed = 0
    var failed = 0

    var summary: String {
        guard copied > 0 || failed > 0 else { return "没有导入成功" }
        var parts: [String] = []
        if copied > 0 { parts.append("导入 \(copied) 个") }
        if renamed > 0 { parts.append("\(renamed) 个同名已改名") }
        if failed > 0 { parts.append("\(failed) 个失败") }
        return parts.joined(separator: "，")
    }
}

/// 待搬进资料库的一个文件
struct ImportItem: Sendable {
    var url: URL
    /// 想要的显示名；nil 时用 URL 自带的名字
    var preferredName: String?
    /// 相册导入的临时文件用 move，省掉一次完整拷贝
    var moving: Bool

    init(url: URL, preferredName: String? = nil, moving: Bool = false) {
        self.url = url
        self.preferredName = preferredName
        self.moving = moving
    }
}

enum ImportService {
    /// 搬一个文件进目标目录。
    ///
    /// 文件 I/O 全部在 detached task 里跑：以前 `copyItem` 是在主线程同步执行的，
    /// 从「文件」导入几段 4K 会把整个界面冻住几十秒，看起来像卡死。
    static func bring(_ item: ImportItem, into target: URL) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            let preferred = item.preferredName ?? item.url.lastPathComponent
            let destination = FileManager.default.uniqueURL(in: target, preferredName: preferred)
            let scoped = item.url.startAccessingSecurityScopedResource()
            defer { if scoped { item.url.stopAccessingSecurityScopedResource() } }

            do {
                if item.moving {
                    try FileManager.default.moveItem(at: item.url, to: destination)
                } else {
                    try FileManager.default.copyItem(at: item.url, to: destination)
                }
            } catch {
                return ImportResult(total: 1, copied: 0, renamed: 0, failed: 1)
            }

            let renamed = destination.lastPathComponent != preferred
            return ImportResult(total: 1, copied: 1, renamed: renamed ? 1 : 0, failed: 0)
        }.value
    }
}
