import UIKit

/// 方向策略：
/// - 资料库、设置等所有页面**永远竖屏**
/// - 只有播放页按设置里的「播放页方向」走（跟随系统 / 竖屏 / 横屏）
///
/// `AppDelegate` 通过 `supportedInterfaceOrientationsFor` 取 `activeMask`；
/// 进 / 出播放页时这里再主动请求一次转屏，不必等用户把手机转回来。
final class OrientationController {
    static let shared = OrientationController()

    /// 设置里选的方向，**只作用于播放页**
    private(set) var playerMask: UIInterfaceOrientationMask = .allButUpsideDown

    /// 播放页是否在前台；其余页面一律竖屏
    private var playerActive = false

    /// 真正交给系统的掩码
    var activeMask: UIInterfaceOrientationMask {
        playerActive ? playerMask : .portrait
    }

    /// 设置里改了方向。不在播放页时只更新内存，不转屏。
    func apply(_ orientation: AppSettings.Orientation) {
        playerMask = Self.mask(for: orientation)
        if playerActive { commit() } else { notifyControllers() }
    }

    /// 进入 / 退出播放页
    func setPlayerActive(_ active: Bool) {
        guard playerActive != active else { return }
        playerActive = active
        commit()
    }

    /// 启动时把存档里的方向读进内存。此时不在播放页，所以不请求转屏，
    /// 系统会按 `activeMask` 的竖屏启动。
    func restore() {
        playerMask = Self.mask(for: AppSettings.storedOrientation())
        notifyControllers()
    }

    // MARK: - 私有

    private static func mask(for orientation: AppSettings.Orientation) -> UIInterfaceOrientationMask {
        switch orientation {
        case .system: return .allButUpsideDown
        case .portrait: return .portrait
        case .landscape: return .landscape
        }
    }

    private var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    /// 逐个窗口、逐个被呈现的控制器通知一遍：只通知根控制器时，
    /// 挂在它上面的覆盖层会继续用旧方向。
    private func notifyControllers() {
        guard let scene else { return }
        for window in scene.windows {
            var controller = window.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
        }
    }

    /// 先让系统知道新掩码，再请求转屏，否则会按旧方向拒绝。
    /// 放到下一个 runloop：进/出播放页时视图可能还没完成布局，
    /// 这一帧请求转屏会被系统忽略。
    private func commit() {
        notifyControllers()
        DispatchQueue.main.async { [weak self] in
            guard let self, let scene = self.scene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: self.activeMask)) { _ in }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationController.shared.activeMask
    }
}
