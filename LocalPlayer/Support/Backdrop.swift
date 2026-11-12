import SwiftUI

/// 页面底色。
///
/// 纯 #0A0A0B 的死黑背景上，再好的玻璃也只能透出黑——看起来就是一块灰。
/// 这里在顶部压一层极淡的冷光（很暗，不抢内容），玻璃透过去才有明暗变化，
/// 顶部那圈白边才立得住，这才是"液态玻璃"而不是"灰塑料"。
struct ScreenBackdrop: View {
    /// 光晕强度，0 等于纯色底
    var glow: Double = 0.26

    var body: some View {
        ZStack {
            Palette.background

            RadialGradient(
                colors: [
                    Color(red: 0.62, green: 0.66, blue: 0.78).opacity(glow),
                    Color(red: 0.40, green: 0.44, blue: 0.56).opacity(glow * 0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 560
            )

            // 底部再垫一点点反光，避免下半屏整块死黑
            LinearGradient(
                colors: [Color.clear, Color(red: 0.30, green: 0.32, blue: 0.38).opacity(glow * 0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
