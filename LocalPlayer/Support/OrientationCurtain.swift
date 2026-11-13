import SwiftUI
import UIKit

/// 转屏幕布。
///
/// 「跟随系统」模式下退出播放页、或设置成横屏进入播放页时，系统会播放一次
/// 约 0.35 秒的旋转动画，观感上是「界面猛地拧过去」。这里在转屏前先拉起
/// 一层近实心黑幕，转屏发生在幕布后面，幕布中央给一枚转向的小手机动画，
/// 把「被迫旋转」变成「换幕时灯暗一下」——这也是 App 名字的出处。
///
/// 用法：`OrientationCurtain.shared.perform(.portrait) { 关掉播放页 }`
@MainActor
final class OrientationCurtain: ObservableObject {
    static let shared = OrientationCurtain()

    enum Hint {
        case portrait   // 即将转回竖屏
        case landscape  // 即将转入横屏
    }

    @Published private(set) var isShowing = false
    @Published private(set) var hint: Hint = .portrait

    private var hideTask: Task<Void, Never>?
    private var workTask: Task<Void, Never>?

    // MARK: - 转屏预判

    /// 系统界面当前是否横屏（退出播放页时会不会发生转屏）
    static var interfaceIsLandscape: Bool {
        switch Self.foregroundScene?.interfaceOrientation {
        case .landscapeLeft, .landscapeRight: return true
        default: return false
        }
    }

    /// 手机是否正被横握（跟随系统模式下进入播放页会不会转）
    static var deviceIsLandscape: Bool {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight: return true
        default: return false
        }
    }

    private static var foregroundScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    // MARK: - 演出

    /// 拉幕 → 幕布盖住后执行 `action`（转屏发生在幕布后面）→ 拉开幕布。
    /// 幕布期间拦截所有触摸，避免转屏途中误点。
    func perform(_ hint: Hint, during action: @escaping @MainActor () -> Void) {
        hideTask?.cancel()
        workTask?.cancel()
        self.hint = hint
        withAnimation(.easeIn(duration: 0.13)) { isShowing = true }

        workTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            action()
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            withAnimation(.easeOut(duration: 0.24)) { self.isShowing = false }
        }
    }
}

/// 挂在根视图上的全屏幕布。平时完全透明、不拦截触摸，只在 `perform` 期间出现。
struct OrientationCurtainView: View {
    @ObservedObject private var curtain = OrientationCurtain.shared
    @State private var iconAngle: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(curtain.isShowing ? 0.94 : 0)

            if curtain.isShowing {
                VStack(spacing: 14) {
                    deviceIcon
                    Text(curtain.hint == .portrait ? "竖屏观看" : "横屏观看")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(curtain.isShowing)
        .onAppear(perform: syncAngle)
        .onChange(of: curtain.hint) { _ in syncAngle() }
    }

    /// 一枚极简的小手机（圆角矩形 + 听筒点），弹簧式转过去
    private var deviceIcon: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .frame(width: 17, height: 30)
            .overlay {
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 6, height: 2)
                    .offset(y: 11)
            }
            .rotationEffect(.degrees(iconAngle))
    }

    /// 起手摆在另一头，下一帧弹簧转到目标方向，看起来像手机自己转了过去
    private func syncAngle() {
        guard curtain.isShowing else { return }
        iconAngle = curtain.hint == .portrait ? 90 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                iconAngle = curtain.hint == .portrait ? 0 : 90
            }
        }
    }
}
