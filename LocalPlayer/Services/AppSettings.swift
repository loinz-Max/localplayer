import SwiftUI
import Combine

/// 设置项直接落在 UserDefaults 上，读写即时生效，避免 @Published + 观察者的兼容问题
final class AppSettings: ObservableObject {
    /// 键名集中一处。播放页这类拿不到 EnvironmentObject 的地方，
    /// 用下面的 static 读取入口，不要再自己拼字符串键。
    enum Key {
        static let resumePlayback = "resumePlayback"
        static let defaultRate = "defaultRate"
        static let defaultPlayMode = "defaultPlayMode"
        static let sortKey = "sortKey"
        static let sortAscending = "sortAscending"
        static let autoHideDelay = "autoHideDelay"
    }

    private let d = UserDefaults.standard

    private func read<T>(_ key: String, _ fallback: T) -> T {
        (d.object(forKey: key) as? T) ?? fallback
    }

    private func write<T>(_ key: String, _ value: T) {
        d.set(value, forKey: key)
        objectWillChange.send()
    }

    /// 断点续播
    var resumePlayback: Bool {
        get { read(Key.resumePlayback, true) }
        set { write(Key.resumePlayback, newValue) }
    }

    /// 默认倍速。进入播放页时的起始值，播放页抽屉里可以临时改
    var defaultRate: Double {
        get { read(Key.defaultRate, 1.0) }
        set { write(Key.defaultRate, newValue) }
    }

    /// 默认播放模式：播完暂停 / 单集循环 / 列表循环
    var defaultPlayMode: PlayMode {
        get {
            let raw = read(Key.defaultPlayMode, PlayMode.loopAll.rawValue)
            return PlayMode(rawValue: raw) ?? .loopAll
        }
        set { write(Key.defaultPlayMode, newValue.rawValue) }
    }

    /// 界面里的排序依据
    var sortKey: SortKey {
        get {
            let raw = read(Key.sortKey, SortKey.recent.rawValue)
            return SortKey(rawValue: raw) ?? .recent
        }
        set { write(Key.sortKey, newValue.rawValue) }
    }

    /// 升序（true）/ 降序（false）
    var sortAscending: Bool {
        get { read(Key.sortAscending, false) }
        set { write(Key.sortAscending, newValue) }
    }

    /// 播放页控件自动隐藏的秒数：2 / 4 / 6
    var autoHideDelay: Double {
        get { read(Key.autoHideDelay, 4.0) }
        set { write(Key.autoHideDelay, newValue) }
    }
}

// MARK: - 播放页的初始值

extension AppSettings {
    /// 播放页挂在 fullScreenCover 里，init 阶段拿不到 EnvironmentObject，
    /// 所以用这两个静态入口读当前默认值；键名仍然只在 Key 里定义一次。
    static func storedRate() -> Double {
        (UserDefaults.standard.object(forKey: Key.defaultRate) as? Double) ?? 1.0
    }

    static func storedPlayMode() -> PlayMode {
        let raw = (UserDefaults.standard.object(forKey: Key.defaultPlayMode) as? String)
            ?? PlayMode.loopAll.rawValue
        return PlayMode(rawValue: raw) ?? .loopAll
    }
}
