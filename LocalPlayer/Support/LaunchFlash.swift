import SwiftUI

/// 冷启动的品牌一闪：黑底上棱镜 logo 快速浮现又淡出，约 1 秒。
///
/// 克制原则：只做一次透明度的起落，没有位移、没有放大、没有标语——
/// 它是「灯亮之前的一瞬」，不是开屏广告。整个生命期不拦截触摸。
struct LaunchFlash: View {
    @State private var visible = false
    @State private var removed = false

    var body: some View {
        Group {
            if !removed {
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image("LaunchLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
                        }
                        .opacity(visible ? 1 : 0)
                        .scaleEffect(visible ? 1 : 0.94)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear { run() }
    }

    private func run() {
        // 灯还没亮：logo 慢慢浮现（0.28s）
        withAnimation(.easeOut(duration: 0.28)) { visible = true }
        // 停留约半秒后，连 logo 带黑底一起淡出，露出资料库
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.easeIn(duration: 0.32)) { visible = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) {
            removed = true
        }
    }
}
