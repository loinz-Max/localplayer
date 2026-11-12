import AVFoundation
import MediaPlayer
import UIKit

/// 把「正在播放」交给系统：锁屏、控制中心、AirPods、车机、Siri 都能显示与控制。
///
/// 两件事各占一半：
/// - 上报：`MPNowPlayingInfoCenter` 写入标题、副标题、时长、进度、倍速、封面
/// - 接收：`MPRemoteCommandCenter` 注册播放/暂停/跳转/拖动，回调转发给 PlayerModel
///
/// 所有回调都是 `DispatchQueue.main` 上执行的，调用方可以放心直接改 UI 状态。
final class NowPlayingService {
    static let shared = NowPlayingService()

    // 由播放页注入
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?
    var onSkip: ((Double) -> Void)?
    var onSeek: ((Double) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

    private var currentItem: VideoItem?
    private var artwork: MPMediaItemArtwork?
    private var artworkFor: String?
    private var isCommandsReady = false
    private var isSessionReady = false
    private var resumableAfterInterruption = false
    private var interruptionToken: NSObjectProtocol?
    private var routeToken: NSObjectProtocol?

    /// 进度上报节流：系统会按 rate 自己外推，没必要每秒刷好几次
    private var lastElapsed: Double = -1
    private var lastPublishAt = Date.distantPast

    private init() {}

    // MARK: - 生命周期

    func begin(item: VideoItem, elapsed: Double, duration: Double, isPlaying: Bool, rate: Float) {
        self.currentItem = item
        activateSession()
        configureCommands()
        observeSystemEvents()
        loadArtwork(for: item)
        publish(elapsed: elapsed, duration: duration, isPlaying: isPlaying, rate: rate)
    }

    func update(elapsed: Double, duration: Double, isPlaying: Bool, rate: Float, force: Bool = false) {
        guard currentItem != nil else { return }
        let drift = abs(elapsed - lastElapsed)
        let elapsedSince = Date().timeIntervalSince(lastPublishAt)
        guard force || drift >= 1.2 || elapsedSince >= 3 else { return }
        publish(elapsed: elapsed, duration: duration, isPlaying: isPlaying, rate: rate)
    }

    func deactivate() {
        onPlay = nil
        onPause = nil
        onToggle = nil
        onSkip = nil
        onSeek = nil
        onNext = nil
        onPrevious = nil

        currentItem = nil
        artwork = nil
        artworkFor = nil
        lastElapsed = -1

        if isCommandsReady {
            let center = MPRemoteCommandCenter.shared()
            [
                center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                center.skipForwardCommand, center.skipBackwardCommand,
                center.changePlaybackPositionCommand,
                center.nextTrackCommand, center.previousTrackCommand
            ].forEach { $0.removeTarget(nil) }
            isCommandsReady = false
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped

        if let interruptionToken { NotificationCenter.default.removeObserver(interruptionToken) }
        if let routeToken { NotificationCenter.default.removeObserver(routeToken) }
        interruptionToken = nil
        routeToken = nil

        if isSessionReady {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            isSessionReady = false
        }
    }

    // MARK: - 音频会话

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        // moviePlayback：告诉系统这是长视频，锁屏卡片的排版与手势按视频处理
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)
        isSessionReady = true
    }

    // MARK: - 上报

    private func publish(elapsed: Double, duration: Double, isPlaying: Bool, rate: Float) {
        guard let item = currentItem else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.displayName,
            MPMediaItemPropertyArtist: item.folder.isEmpty ? "幕间" : (item.folder as NSString).lastPathComponent,
            MPMediaItemPropertyAlbumTitle: "幕间",
            MPMediaItemPropertyPlaybackDuration: max(duration, 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsed, 0),
            // 暂停时必须是 0，否则锁屏进度条会自己继续往前走
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]

        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        lastElapsed = elapsed
        lastPublishAt = Date()
    }

    /// 封面用卡片那张缩略图，512 是锁屏大图档位；生成失败就不放图，系统会显示默认方块
    private func loadArtwork(for item: VideoItem) {
        guard artworkFor != item.id else { return }
        artworkFor = item.id
        artwork = nil

        ThumbnailLoader.shared.load(for: item, size: CGSize(width: 512, height: 512)) { [weak self] image in
            guard let self, let image, self.currentItem?.id == item.id else { return }
            DispatchQueue.main.async {
                self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                // 图是异步到的，到了再补一次，别等下次进度刷新
                self.republishCurrent()
            }
        }
    }

    /// 用上一次的数字原样再写一次（封面后到、或系统清空了卡片）
    private func republishCurrent() {
        guard let item = currentItem else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = item.displayName
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 接收

    private func configureCommands() {
        guard !isCommandsReady else { return }
        isCommandsReady = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.run { $0.onPlay?() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.run { $0.onPause?() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.run { $0.onToggle?() }
            return .success
        }

        // 耳机线控 / 锁屏的 ±10 秒，和 App 内双击保持同一个步长
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 10)]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            self?.run { $0.onSkip?(interval) }
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 10)]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            self?.run { $0.onSkip?(-interval) }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            self?.run { $0.onSeek?(position) }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.run { $0.onNext?() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.run { $0.onPrevious?() }
            return .success
        }
    }

    private func run(_ body: @escaping (NowPlayingService) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            body(self)
        }
    }

    // MARK: - 系统事件

    private func observeSystemEvents() {
        if let interruptionToken { NotificationCenter.default.removeObserver(interruptionToken) }
        if let routeToken { NotificationCenter.default.removeObserver(routeToken) }

        interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

            switch type {
            case .began:
                // 来电话 / 闹钟：先记下原本在播，结束后再决定要不要接着放
                self.resumableAfterInterruption = MPNowPlayingInfoCenter.default().playbackState == .playing
                self.onPause?()
            case .ended:
                let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
                if options.contains(.shouldResume), self.resumableAfterInterruption {
                    self.onPlay?()
                }
                self.resumableAfterInterruption = false
            @unknown default:
                break
            }
        }

        routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            // 拔耳机 / 断开蓝牙：跟着暂停，别突然外放
            if reason == .oldDeviceUnavailable {
                self.onPause?()
            }
        }
    }
}
