import AVKit
import AVFoundation
import UIKit

/// 画中画。
///
/// 播放页点画中画按钮后，全屏界面退出、视频缩进系统小窗继续播。
/// 关键点：AVPlayer 挂在一个 6×6 的常驻小视图上（挂在 key window 上、alpha 0.02），
/// 播放页关闭后图层仍在层级里，画中画才不会被掐断。
///
/// 流程：
/// 1. `start(player:item:queue:progress:)` 建控制器并 `startPictureInPicture()`
/// 2. `didStart` → `isActive = true`，播放页观察到后自动退出（teardown 跳过清理）
/// 3. 用户在小窗点「展开」→ `restoreUserInterfaceFor…` → 发 `restoreNotification`，
///    资料库收到后重新拉起播放页（带转屏幕布）；进度已按 4 秒节流存进 ProgressStore
/// 4. 用户在小窗点「关闭」→ `didStop` → 暂停、存进度、注销锁屏卡片
final class PiPService: NSObject, ObservableObject {
    static let shared = PiPService()

    /// 用户在小窗点「展开」时的恢复请求。userInfo：`item: VideoItem`、`queue: [VideoItem]`
    static let restoreNotification = Notification.Name("pipRestore")

    /// 画中画接管中。播放页据此跳过 teardown 的 pause / replaceCurrentItem，
    /// 否则 AVPlayer 的 currentItem 一被清掉，小窗立刻黑屏。
    @Published private(set) var isActive = false

    private var controller: AVPictureInPictureController?
    private var layer: AVPlayerLayer?
    private var player: AVPlayer?
    private var item: VideoItem?
    private var queue: [VideoItem] = []
    private weak var progress: ProgressStore?
    private var saveTimer: Timer?

    /// 画中画源图层的小宿主。保持挂在窗口层级上，尺寸做到肉眼不可见。
    private let hostView = UIView(frame: CGRect(x: -2, y: -2, width: 6, height: 6))

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    /// 这个 player 是否正被画中画接管（teardown 判断用）
    func isTakingOver(_ candidate: AVPlayer) -> Bool { isActive && player === candidate }

    func start(player: AVPlayer, item: VideoItem, queue: [VideoItem], progress: ProgressStore?) {
        guard isSupported else { return }
        attachHostIfNeeded()

        // 换了 player 就重建控制器；同一个 player 复用旧控制器
        if controller == nil || self.player !== player {
            layer?.removeFromSuperlayer()
            let newLayer = AVPlayerLayer()
            newLayer.player = player
            newLayer.frame = CGRect(x: 0, y: 0, width: 6, height: 6)
            hostView.layer.addSublayer(newLayer)
            layer = newLayer

            guard let newController = AVPictureInPictureController(playerLayer: newLayer) else { return }
            newController.delegate = self
            controller = newController
        }

        self.player = player
        self.item = item
        self.queue = queue
        self.progress = progress

        controller?.startPictureInPicture()
    }

    // MARK: - 私有

    private func attachHostIfNeeded() {
        guard hostView.superview == nil else { return }
        hostView.alpha = 0.02
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        window?.addSubview(hostView)
    }

    /// 画中画期间周期性存进度——播放页已经关了，没人再写 ProgressStore
    private func startSaving() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.saveProgress()
        }
    }

    private func saveProgress() {
        guard let player, let item else { return }
        let time = player.currentTime().seconds
        let total = player.currentItem?.duration.seconds ?? 0
        guard time.isFinite, total > 1 else { return }
        progress?.update(id: item.id, time: time, total: total)
    }

    /// 画中画彻底结束（关闭或展开转回全屏）后清理现场
    private func finish(saveAndPause: Bool) {
        saveTimer?.invalidate()
        saveTimer = nil
        if saveAndPause {
            saveProgress()
            player?.pause()
            NowPlayingService.shared.deactivate()
        }
        isActive = false
        controller = nil
        player = nil
        item = nil
        queue = []
        layer?.removeFromSuperlayer()
        layer = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPService: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        DispatchQueue.main.async {
            guard self.controller === pictureInPictureController else { return }
            self.isActive = true
            self.startSaving()
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        DispatchQueue.main.async {
            guard self.controller === pictureInPictureController else { return }
            self.finish(saveAndPause: true)
        }
    }

    /// 用户在小窗点「展开」：先把播放页拉起来，再答复系统「界面已恢复」
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async {
            guard self.controller === pictureInPictureController else {
                completionHandler(false)
                return
            }
            self.saveProgress()
            let item = self.item
            let queue = self.queue
            self.finish(saveAndPause: false)

            if let item {
                NotificationCenter.default.post(
                    name: Self.restoreNotification,
                    object: nil,
                    userInfo: ["item": item, "queue": queue]
                )
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
}
