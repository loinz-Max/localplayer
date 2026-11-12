import UIKit

/// 全局方向锁。设置里选「跟随系统 / 竖屏锁定 / 横屏锁定」，
/// AppDelegate 通过 `supportedInterfaceOrientationsFor` 把这个 mask 交给系统，
/// 改设置时再主动请求转一次屏，不必等用户把手机转回来。
final class OrientationController {
    static let shared = OrientationController()

    private(set) var mask: UIInterfaceOrientationMask = .allButUpsideDown

    func apply(_ orientation: AppSettings.Orientation) {
        let newMask: UIInterfaceOrientationMask
        switch orientation {
        case .system: newMask = .allButUpsideDown
        case .portrait: newMask = .portrait
        case .landscape: newMask = .landscape
        }
        mask = newMask

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        // 先把新的 mask 通知下去，再请求转屏，否则系统会按旧方向拒绝。
        // 逐个窗口、逐个被呈现的控制器通知一遍：只通知根控制器时，
        // 挂在它上面的 sheet / 覆盖层会继续用旧方向。
        for window in scene.windows {
            var controller = window.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in }
    }

    /// 启动时把设置里存的方向落到系统上
    func restore() {
        apply(AppSettings.storedOrientation())
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationController.shared.mask
    }
}
