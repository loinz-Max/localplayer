import SwiftUI
import AVFoundation
import AVKit
import UIKit

// MARK: - 入口（负责「同目录下一个视频」的切换）

struct PlayerScreen: View {
    let queue: [VideoItem]

    @State private var current: VideoItem
    /// 倍速与模式只在本次播放有效：放在这一层，切集不丢，退出播放页即丢
    @State private var rate: Double
    @State private var mode: PlayMode
    /// 播放列表抽屉开着就去切集，切完仍然开着（与之前一致）
    @State private var queueOpen = false

    @Environment(\.dismiss) private var dismiss

    init(item: VideoItem, queue: [VideoItem]) {
        self.queue = queue
        _current = State(initialValue: item)
        // 起始倍速/模式从设置里取；键名与读写都收在 AppSettings 里
        _rate = State(initialValue: AppSettings.storedRate())
        _mode = State(initialValue: AppSettings.storedPlayMode())
    }

    var body: some View {
        PlayerCore(
            item: current,
            queue: queue,
            rate: $rate,
            mode: $mode,
            queueOpen: $queueOpen,
            onClose: { dismiss() },
            onAdvance: { next in
                if let next {
                    current = next
                } else {
                    dismiss()
                }
            }
        )
        .id(current.id)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 临时状态

private enum DragMode {
    case none, seek, brightness, volume
}

private struct HUD: Equatable {
    var icon: String
    var text: String
    var progress: Double?
}

/// 亮度 / 音量：只有一个数值，画成顶部的一根细条
private struct LevelHUD: Equatable {
    /// 0…1
    var value: Double
}

// MARK: - 播放页主体

private struct PlayerCore: View {
    let item: VideoItem
    let queue: [VideoItem]
    @Binding var rate: Double
    @Binding var mode: PlayMode
    @Binding var queueOpen: Bool
    var onClose: () -> Void
    var onAdvance: (VideoItem?) -> Void

    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @StateObject private var model: PlayerModel

    @State private var chromeVisible = true
    @State private var hideToken = 0
    @State private var speedOpen = false
    @State private var toastText: String?

    /// 画面比例：本次播放内有效
    @State private var gravityIndex: Int

    /// 防误触：锁上后除了「长按 1 秒解除」以外的所有触摸都不响应
    @State private var touchLocked = false

    @State private var hud: HUD?
    @State private var hudToken = 0

    /// 亮度 / 音量：顶部居中的横向长条，不占画面中间
    @State private var level: LevelHUD?
    @State private var levelToken = 0

    @State private var dragMode: DragMode = .none
    @State private var dragStartTime: Double = 0
    @State private var seekTarget: Double = 0
    @State private var brightnessStart: CGFloat = 0
    @State private var volumeStart: Float = 0

    @State private var boosting = false
    /// 按下计时令牌：松手/重新按下都会让旧的延时失效
    @State private var pressToken = 0
    /// 锁定状态下点击屏幕后，只把解锁按钮亮出来
    @State private var lockButtonVisible = false

    @State private var scrubFraction: Double?
    @State private var isScrubbing = false

    @State private var pendingResume: Double = 0
    @State private var didRestore = false
    @State private var lastSavedAt: Double = 0

    init(
        item: VideoItem,
        queue: [VideoItem],
        rate: Binding<Double>,
        mode: Binding<PlayMode>,
        queueOpen: Binding<Bool>,
        onClose: @escaping () -> Void,
        onAdvance: @escaping (VideoItem?) -> Void
    ) {
        self.item = item
        self.queue = queue
        _rate = rate
        _mode = mode
        _queueOpen = queueOpen
        self.onClose = onClose
        self.onAdvance = onAdvance
        _model = StateObject(wrappedValue: PlayerModel(item: item, resumeTime: 0, rate: 1))
        // 画面比例按设置里的默认值起步，本次改不回写设置（保持「本次有效」的约定）
        _gravityIndex = State(initialValue: AppSettings.storedGravity())
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// 抽屉展开时整层控件收起；倍速面板是浮层，控件保持可见
    private var showControls: Bool { chromeVisible && !queueOpen }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                VideoSurface(player: model.player, gravity: gravity) { _ in }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(size: geo.size))
                    .highPriorityGesture(doubleTapGesture(size: geo.size))
                    .onTapGesture { handleTap() }
                    .onLongPressGesture(
                        minimumDuration: 0.6,
                        maximumDistance: 60,
                        perform: {},
                        onPressingChanged: { pressing in
                            handlePressChange(pressing)
                        }
                    )
                    .simultaneousGesture(magnifyGesture)
            }
            .ignoresSafeArea()

            if queueOpen {
                // 抽屉展开时整层控件收起，画面与抽屉互不遮挡
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { closeQueue() }
                    .transition(.opacity)
            }

            if showControls {
                controlsLayer
                    .transition(.opacity)
            }

            speedPanelLayer

            hudLayer

            if boosting {
                boostHint
            }

            if let level {
                levelBar(level)
            }

            if touchLocked {
                lockLayer
            }

            if let toastText {
                toastView(toastText)
            }

            if let failed = model.failed {
                errorLayer(failed)
            }
        }
        .overlay(alignment: .trailing) { queueLayer }
        .background(Color.black)
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onChange(of: rate) { _, value in
            model.setRate(Float(value))
        }
        .onChange(of: settings.keepAwake) { _, value in
            UIApplication.shared.isIdleTimerDisabled = value
        }
        .onChange(of: touchLocked) { _, locked in
            if locked { engageLock() }
        }
        .onChange(of: queueOpen) { _, open in
            if open {
                hideToken += 1
                speedOpen = false
            } else if !touchLocked {
                showChrome(persistent: false)
            }
        }
        .onChange(of: model.duration) { _, value in
            if !didRestore, value > 0 { restorePosition() }
        }
        .onChange(of: model.isPlaying) { _, playing in
            if playing {
                scheduleHide()
            } else {
                showChrome(persistent: true)
            }
        }
        .onChange(of: model.currentTime) { _, _ in
            maybeSaveProgress()
        }
    }

    private var gravity: AVLayerVideoGravity {
        switch gravityIndex {
        case 1: return .resizeAspectFill
        case 2: return .resize
        default: return .resizeAspect
        }
    }

    // MARK: - 手势

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in handleDragChanged(value, size: size) }
            .onEnded { _ in handleDragEnded() }
    }

    private func doubleTapGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                guard !touchLocked else { return }
                speedOpen = false
                showChrome(persistent: false)
                if value.location.x < size.width * 0.35 {
                    model.skip(-10)
                } else if value.location.x > size.width * 0.65 {
                    model.skip(10)
                } else {
                    model.togglePlay()
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                guard !touchLocked else { return }
                if value.magnification > 1.05 {
                    gravityIndex = 1
                } else if value.magnification < 0.95 {
                    gravityIndex = 0
                }
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value, size: CGSize) {
        guard !touchLocked else { return }
        if dragMode == .none {
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            guard max(dx, dy) > 6 else { return }

            speedOpen = false

            if dx > dy {
                dragMode = .seek
                dragStartTime = model.currentTime
                seekTarget = model.currentTime
                showChrome(persistent: false)
            } else if value.startLocation.x < size.width / 2 {
                dragMode = .brightness
                brightnessStart = ScreenBrightness.current
            } else {
                dragMode = .volume
                volumeStart = SystemVolume.shared.value
            }
        }

        switch dragMode {
        case .seek:
            let span = min(max(model.duration * 0.4, 60), 240)
            let ratio = Double(value.translation.width / max(size.width, 1))
            let target = min(max(0, dragStartTime + ratio * span), max(model.duration - 0.5, 0))
            seekTarget = target
            hud = HUD(
                icon: "timeline.selection",
                text: "\(Fmt.time(target)) / \(Fmt.time(model.duration))",
                progress: model.duration > 0 ? target / model.duration : nil
            )

        case .brightness:
            let delta = -value.translation.height / max(size.height * 0.6, 1)
            let next = min(max(brightnessStart + delta, 0), 1)
            ScreenBrightness.set(next)
            level = LevelHUD(value: Double(next))

        case .volume:
            let delta = Float(-value.translation.height / max(size.height * 0.6, 1))
            let next = min(max(volumeStart + delta, 0), 1)
            SystemVolume.shared.set(next)
            level = LevelHUD(value: Double(next))

        case .none:
            break
        }
    }

    private func handleDragEnded() {
        if dragMode == .seek {
            model.seek(to: seekTarget)
            fadeHUD(after: 0.6)
        }
        if dragMode == .brightness || dragMode == .volume {
            fadeLevel(after: 0.5)
        }
        dragMode = .none
    }

    private func fadeLevel(after delay: Double) {
        levelToken += 1
        let token = levelToken
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if levelToken == token {
                withAnimation(.easeOut(duration: 0.25)) { level = nil }
            }
        }
    }

    /// 按住 0.28 秒进 2×，一松手立刻回原速。
    ///
    /// 不用 `perform`：它要等 minimumDuration 才触发，而松手与触发谁先谁后不确定，
    /// 会出现「松手后才变 2×、然后再也不回来」。这里直接用 pressing 自己计时。
    private func handlePressChange(_ pressing: Bool) {
        pressToken += 1
        let token = pressToken

        guard pressing else {
            endBoost()
            return
        }

        // 暂停、锁定、抽屉/面板打开时不响应
        guard !touchLocked, !queueOpen, model.isPlaying, !speedOpen else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard pressToken == token, !boosting else { return }
            withAnimation(.easeOut(duration: 0.12)) { boosting = true }
            model.setRate(2)
        }
    }

    private func endBoost() {
        guard boosting else { return }
        withAnimation(.easeOut(duration: 0.12)) { boosting = false }
        model.setRate(Float(rate))
    }

    private func handleTap() {
        if touchLocked {
            toggleLockButton()
            return
        }
        if speedOpen {
            withAnimation(.easeOut(duration: 0.16)) { speedOpen = false }
        } else if queueOpen {
            closeQueue()
        } else {
            toggleChrome()
        }
    }

    // MARK: - HUD / 显隐

    private func flashHUD(_ value: HUD, duration: Double = 0.9) {
        hudToken += 1
        hud = value
        fadeHUD(after: duration)
    }

    private func fadeHUD(after delay: Double) {
        let token = hudToken
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if hudToken == token {
                withAnimation(.easeOut(duration: 0.2)) { hud = nil }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.2)) { toastText = nil }
        }
    }

    private func toggleChrome() {
        if chromeVisible {
            hideToken += 1
            withAnimation(.easeInOut(duration: 0.2)) { chromeVisible = false }
        } else {
            showChrome(persistent: false)
        }
    }

    private func showChrome(persistent: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible = true }
        hideToken += 1
        if persistent { return }
        scheduleHide()
    }

    private func scheduleHide() {
        #if DEBUG
        if DebugSeed.argument(after: "-keepChrome") == "1" { return }
        #endif
        guard !touchLocked, !queueOpen, !speedOpen else { return }
        hideToken += 1
        let token = hideToken
        guard model.isPlaying else { return }
        let delay = max(1, settings.autoHideDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if hideToken == token, model.isPlaying, !queueOpen, !speedOpen {
                withAnimation(.easeInOut(duration: 0.2)) { chromeVisible = false }
            }
        }
    }

    // MARK: - 防误触

    /// 锁上：收起抽屉、倍速面板与控件，只在开头 2.5 秒提示怎么解锁
    private func engageLock() {
        hideToken += 1
        withAnimation(.easeOut(duration: 0.2)) {
            queueOpen = false
            speedOpen = false
            lockButtonVisible = false
        }
        withAnimation(.easeInOut(duration: 0.2)) { chromeVisible = false }
        hud = nil
        level = nil
    }

    /// 锁定状态下点屏幕：只把解锁按钮亮出来，3 秒后自己收回去
    private func toggleLockButton() {
        hideToken += 1
        let token = hideToken
        withAnimation(.easeOut(duration: 0.16)) { lockButtonVisible = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if hideToken == token, touchLocked {
                withAnimation(.easeIn(duration: 0.2)) { lockButtonVisible = false }
            }
        }
    }

    private func unlock() {
        withAnimation(.easeOut(duration: 0.2)) {
            touchLocked = false
            lockButtonVisible = false
        }
        showChrome(persistent: false)
    }

    /// 锁定时铺满全屏的触摸拦截层：单击无视，长按 1 秒解除
    /// 锁定时铺一层透明接点击：点屏幕只亮出左下角的解锁按钮，不做任何手势
    private var lockLayer: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { toggleLockButton() }

            if lockButtonVisible {
                Button {
                    unlock()
                } label: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glass(Circle(), style: .stage)
                .padding(.leading, isLandscape ? 16 : 20)
                .padding(.bottom, isLandscape ? 16 : 26)
                .transition(.opacity)
            }
        }
        .transition(.opacity)
    }

    // MARK: - 抽屉 / 倍速

    private func openQueue() {
        hideToken += 1
        withAnimation(.easeOut(duration: 0.22)) {
            queueOpen.toggle()
            chromeVisible = false
        }
    }

    private func closeQueue() {
        hideToken += 1
        withAnimation(.easeOut(duration: 0.2)) { queueOpen = false }
        showChrome(persistent: false)
    }

    private func toggleSpeed() {
        hideToken += 1
        withAnimation(.easeOut(duration: 0.16)) { speedOpen.toggle() }
    }

    // MARK: - 控制层

    private var controlsLayer: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
            }

            centerTransport

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomBar
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            GlassIconButton(
                systemName: "xmark",
                size: 38,
                iconSize: 15,
                weight: .semibold,
                style: .stage
            ) { onClose() }

            Spacer(minLength: 0)

            GlassIconButton(
                systemName: "list.bullet",
                size: 38,
                iconSize: 16,
                weight: .medium,
                style: .stage
            ) { openQueue() }
        }
        .padding(.horizontal, 20)
        .padding(.top, isLandscape ? 12 : 6)
    }

    /// 中部三圆：等大、靠图标区分
    private var centerTransport: some View {
        let size: CGFloat = isLandscape ? 62 : 58
        return HStack(spacing: isLandscape ? 30 : 26) {
            circleButton("gobackward.10", size: size, iconSize: isLandscape ? 27 : 25) {
                model.skip(-10)
            }
            circleButton(
                model.isPlaying ? "pause.fill" : "play.fill",
                size: size,
                iconSize: isLandscape ? 26 : 24
            ) {
                model.togglePlay()
            }
            circleButton("goforward.10", size: size, iconSize: isLandscape ? 27 : 25) {
                model.skip(10)
            }
        }
    }

    private func circleButton(
        _ icon: String,
        size: CGFloat,
        iconSize: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), style: .stage)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                lockButton
                Spacer(minLength: 0)
                // 面板展开时不再显示倍速键，避免两个入口同屏
                if !speedOpen {
                    speedButton
                }
            }
            progressCapsule
        }
        .padding(.horizontal, isLandscape ? 16 : 20)
        .padding(.bottom, isLandscape ? 16 : 26)
    }

    /// 左下角的防误触锁，与右下角倍速键对称
    private var lockButton: some View {
        Button {
            touchLocked = true
        } label: {
            Image(systemName: "lock.open")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), style: .stage)
    }

    private var speedButton: some View {
        Button {
            toggleSpeed()
        } label: {
            Text(rateText)
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), style: .stage)
    }

    private var progressCapsule: some View {
        HStack(spacing: 11) {
            Text(Fmt.time(displayTime))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize()

            scrubBar

            Text("-\(Fmt.time(max(0, model.duration - displayTime)))")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize()
        }
        .padding(.horizontal, 15)
        .frame(height: 36)
        .glass(Capsule(), style: .stage)
    }

    private var rateText: String {
        rate == 1 ? "1×" : "\(String(format: "%g", rate))×"
    }

    private var displayTime: Double {
        if isScrubbing, let scrubFraction {
            return scrubFraction * max(model.duration, 0)
        }
        return model.currentTime
    }

    private var playFraction: Double {
        let played = model.duration > 0 ? model.currentTime / model.duration : 0
        return min(max(isScrubbing ? (scrubFraction ?? played) : played, 0), 1)
    }

    private var scrubBar: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.white)
                    .frame(width: width * CGFloat(playFraction), height: 4)

                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    .offset(x: max(0, min(width - 11, width * CGFloat(playFraction) - 5.5)))
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        scrubFraction = Double(min(max(value.location.x / width, 0), 1))
                    }
                    .onEnded { value in
                        let x = min(max(value.location.x / width, 0), 1)
                        model.seek(to: Double(x) * model.duration)
                        isScrubbing = false
                        scrubFraction = nil
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - 倍速面板

    /// 浮在倍速键上方，右缘与倍速键对齐；宽度只有 110，不遮画面中部
    @ViewBuilder
    private var speedPanelLayer: some View {
        if speedOpen {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    SpeedPanel(rate: $rate, isLandscape: isLandscape) {
                        withAnimation(.easeOut(duration: 0.16)) { speedOpen = false }
                        scheduleHide()
                    }
                }
            }
            .padding(.trailing, isLandscape ? 16 : 20)
            // 面板底边正好落在倍速键原来的位置，看起来是从按钮里长出来的
            .padding(.bottom, isLandscape ? 64 : 74)
            .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .bottomTrailing)))
        }
    }

    // MARK: - 抽屉

    @ViewBuilder
    private var queueLayer: some View {
        if queueOpen {
            QueuePanel(queue: queue, current: item, isLandscape: isLandscape) { next in
                if next.id == item.id {
                    closeQueue()
                } else {
                    onAdvance(next)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.vertical, isLandscape ? 0 : 4)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: - 浮层

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glass(Capsule())
                .padding(.bottom, 120)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// 亮度 / 音量提示：屏幕顶部居中的一根细条，没有图标也没有数字
    private func levelBar(_ level: LevelHUD) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.34))
                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: max(4, geo.size.width * CGFloat(min(max(level.value, 0), 1)))
                        )
                }
                .frame(height: 4)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
            .frame(width: 180, height: 4)
            .padding(.top, isLandscape ? 14 : 54)

            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// 长按 2× 的提示：水平居中、顶栏下方一点，做小，绝不压中部按钮
    private var boostHint: some View {
        VStack(spacing: 0) {
            Text("2× 快进")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .glass(Capsule(), style: .stage)
                .padding(.top, isLandscape ? 54 : 60)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder
    private var hudLayer: some View {
        if let hud {
            VStack(spacing: 9) {
                Image(systemName: hud.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)

                Text(hud.text)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let value = hud.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.25))
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, geo.size.width * CGFloat(min(max(value, 0), 1))))
                        }
                    }
                    .frame(width: 120, height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Color.black.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func errorLayer(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text("无法播放")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            if !item.systemPlayable {
                Text("\(item.ext.uppercased()) 容器系统播放器不支持，需要转成 mp4 / mov。")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: onClose) {
                Text("关闭")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 36)
                    .glass(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 330)
        .glass(cornerRadius: 18)
    }

    // MARK: - 生命周期

    private func setup() {
        model.onEnded = { handleEnded() }
        model.setRate(Float(rate))
        pendingResume = settings.resumePlayback ? progress.position(for: item.id) : 0

        model.play()
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
        showChrome(persistent: false)

        // 防误触改成左下角手动锁，不再进页面自动锁
        #if DEBUG
        DebugSeed.forceLandscapeIfRequested()
        // 截图用：直接展开某个浮层，省得截图脚本去点按钮
        if let which = DebugSeed.argument(after: "-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                switch which {
                case "speed": speedOpen = true
                case "lock": touchLocked = true
                case "level": level = LevelHUD(value: 0.62)
                default: queueOpen = true
                }
            }
        }
        #endif
    }

    private func restorePosition() {
        didRestore = true
        guard pendingResume > 5 else { return }
        model.seek(to: pendingResume)
    }

    private func maybeSaveProgress() {
        guard model.duration > 1, model.isPlaying else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastSavedAt > 4 else { return }
        lastSavedAt = now
        progress.update(id: item.id, time: model.currentTime, total: model.duration)
    }

    private func teardown() {
        if model.duration > 1 {
            progress.update(id: item.id, time: model.currentTime, total: model.duration)
        }
        UIApplication.shared.isIdleTimerDisabled = false
        model.cleanup()
    }

    private func handleEnded() {
        progress.clear(id: item.id)

        switch mode {
        case .loopOne:
            model.seek(to: 0)
            model.play()

        case .loopAll:
            if let next = nextItem(wrapping: true), next.id != item.id {
                onAdvance(next)
            } else {
                model.seek(to: 0)
                model.play()
            }

        case .stopAtEnd:
            model.pause()
            showChrome(persistent: true)
        }
    }

    private func nextItem(wrapping: Bool) -> VideoItem? {
        guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return nil }
        let next = index + 1
        if next < queue.count { return queue[next] }
        return wrapping ? queue.first : nil
    }
}
