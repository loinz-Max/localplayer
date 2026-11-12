import SwiftUI
import Combine

/// 设置项直接落在 UserDefaults 上，读写即时生效，避免 @Published + 观察者的兼容问题
final class AppSettings: ObservableObject {
    /// 键名集中一处。播放页这类拿不到 EnvironmentObject 的地方，
    /// 用下面的 static 读取入口，不要再自己拼字符串键。
    enum Key {
        static let resumePlayback = "resumePlayback"
        static let longPressRate = "longPressRate"
        static let defaultPlayMode = "defaultPlayMode"
        static let sortKey = "sortKey"
        static let sortAscending = "sortAscending"
        static let autoHideDelay = "autoHideDelay"
        static let defaultGravity = "defaultGravity"
        static let keepAwake = "keepAwake"
        static let orientationLock = "orientationLock"
        static let libraryView = "libraryView"
    }

    enum LibraryView: String, CaseIterable, Identifiable {
        case grid, list

        var id: String { rawValue }

        var title: String {
            switch self {
            case .grid: return "网格"
            case .list: return "列表"
            }
        }
    }

    enum Orientation: String, CaseIterable, Identifiable {
        case system, portrait, landscape

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "跟随系统"
            case .portrait: return "竖屏锁定"
            case .landscape: return "横屏锁定"
            }
        }
    }

    private let d = UserDefaults.standard

    /// 只做一次：把早期版本留下的「最近播放 / 降序」纠成名称升序。
    /// 之后用户在「⋯」菜单里怎么改都按他的来。
    private static let sortResetKey = "sortResetToNameAscending"

    init() {
        if !UserDefaults.standard.bool(forKey: Self.sortResetKey) {
            UserDefaults.standard.set(SortKey.name.rawValue, forKey: Key.sortKey)
            UserDefaults.standard.set(true, forKey: Key.sortAscending)
            UserDefaults.standard.set(true, forKey: Self.sortResetKey)
        }
    }

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
    /// 长按画面时的倍速（播放页里按住就按这个速度跑）
    var longPressRate: Double {
        get { read(Key.longPressRate, 2.0) }
        set { write(Key.longPressRate, newValue) }
    }

    /// 默认播放模式：播完暂停 / 单集循环 / 列表循环
    var defaultPlayMode: PlayMode {
        get {
            let raw = read(Key.defaultPlayMode, PlayMode.loopAll.rawValue)
            return PlayMode(rawValue: raw) ?? .loopAll
        }
        set { write(Key.defaultPlayMode, newValue.rawValue) }
    }

    /// 界面里的排序依据。默认按名称，跟文件 App 的习惯一致
    var sortKey: SortKey {
        get {
            let raw = read(Key.sortKey, SortKey.name.rawValue)
            return SortKey(rawValue: raw) ?? .name
        }
        set { write(Key.sortKey, newValue.rawValue) }
    }

    /// 升序（true）/ 降序（false）。默认升序
    var sortAscending: Bool {
        get { read(Key.sortAscending, true) }
        set { write(Key.sortAscending, newValue) }
    }

    /// 播放页控件自动隐藏的秒数：2 / 4 / 6
    var autoHideDelay: Double {
        get { read(Key.autoHideDelay, 4.0) }
        set { write(Key.autoHideDelay, newValue) }
    }

    /// 默认画面：0 适应 / 1 填充 / 2 拉伸
    var defaultGravity: Int {
        get { read(Key.defaultGravity, 0) }
        set { write(Key.defaultGravity, newValue) }
    }

    /// 播放时屏幕常亮
    var keepAwake: Bool {
        get { read(Key.keepAwake, true) }
        set { write(Key.keepAwake, newValue) }
    }

    /// 资料库排版：网格 / 列表
    var libraryView: LibraryView {
        get { LibraryView(rawValue: read(Key.libraryView, LibraryView.grid.rawValue)) ?? .grid }
        set { write(Key.libraryView, newValue.rawValue) }
    }

    /// 方向锁定：跟随系统 / 竖屏 / 横屏
    var orientationLock: Orientation {
        get { Orientation(rawValue: read(Key.orientationLock, Orientation.system.rawValue)) ?? .system }
        set {
            write(Key.orientationLock, newValue.rawValue)
            OrientationController.shared.apply(newValue)
        }
    }

    /// 播放页这类地方拿不到 EnvironmentObject 时，直接读存档
    static func storedOrientation() -> Orientation {
        let raw = UserDefaults.standard.string(forKey: Key.orientationLock) ?? ""
        return Orientation(rawValue: raw) ?? .system
    }
}

// MARK: - 播放页的初始值

extension AppSettings {
    /// 播放页挂在 fullScreenCover 里，init 阶段拿不到 EnvironmentObject，
    /// 所以用这两个静态入口读当前默认值；键名仍然只在 Key 里定义一次。
    static func storedLongPressRate() -> Double {
        (UserDefaults.standard.object(forKey: Key.longPressRate) as? Double) ?? 2.0
    }

    static func storedPlayMode() -> PlayMode {
        let raw = (UserDefaults.standard.object(forKey: Key.defaultPlayMode) as? String)
            ?? PlayMode.loopAll.rawValue
        return PlayMode(rawValue: raw) ?? .loopAll
    }

    static func storedGravity() -> Int {
        (UserDefaults.standard.object(forKey: Key.defaultGravity) as? Int) ?? 0
    }
}
