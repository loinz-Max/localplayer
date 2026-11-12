import SwiftUI

/// 液态玻璃配方（对齐 iOS 26 起的 Liquid Glass 观感）：
///   1. `.ultraThinMaterial` —— 真实背景模糊
///   2. 染色层 —— 把材质压到目标明度（浅底用白、压画面用黑）
///   3. 镜面高光 —— 左上角的径向高光，让平面看起来是"凸"的
///   4. 底部厚度 —— 下沿的暗色渐变，制造玻璃的体感
///   5. 边缘光 —— 1pt 渐变描边，上沿最亮、下沿几乎消失
///   6. 外投影 —— 让整块浮在背景之上
///
/// 不直接用原生 `glassEffect`：那需要 Xcode 26 / iOS 26 SDK 才编得过，
/// 而 CI 跑在 macos-15 上；这六层在任何 iOS 17+ 上都能还原同样的观感。
struct GlassStyle {
    var tintTop: Color
    var tintBottom: Color
    /// 镜面高光强度 0…1
    var sheen: Double
    var rimTop: Color
    var rimBottom: Color
    /// 底部内侧厚度 0…1
    var depth: Double
    var shadowRadius: CGFloat
    var shadowY: CGFloat
    var shadowOpacity: Double

    /// 资料库这类深色底上的圆键、胶囊
    static let control = GlassStyle(
        tintTop: Color.white.opacity(0.17),
        tintBottom: Color.white.opacity(0.07),
        sheen: 0.24,
        rimTop: Color.white.opacity(0.62),
        rimBottom: Color.white.opacity(0.12),
        depth: 0.10,
        shadowRadius: 14,
        shadowY: 5,
        shadowOpacity: 0.28
    )

    /// 菜单、抽屉、弹窗
    static let panel = GlassStyle(
        tintTop: Color.black.opacity(0.30),
        tintBottom: Color.black.opacity(0.44),
        sheen: 0.16,
        rimTop: Color.white.opacity(0.52),
        rimBottom: Color.white.opacity(0.08),
        depth: 0.22,
        shadowRadius: 30,
        shadowY: 12,
        shadowOpacity: 0.48
    )

    /// 播放页：压在视频画面上。浅色染色在亮画面上会糊掉，这里用暗色，
    /// 但边缘光要更亮——那是液态玻璃最好认的特征。
    static let stage = GlassStyle(
        tintTop: Color.black.opacity(0.24),
        tintBottom: Color.black.opacity(0.40),
        sheen: 0.20,
        rimTop: Color.white.opacity(0.66),
        rimBottom: Color.white.opacity(0.10),
        depth: 0.20,
        shadowRadius: 16,
        shadowY: 6,
        shadowOpacity: 0.38
    )

    /// 更淡一档，用于进度条这类大面积浅底
    static let subtle = GlassStyle(
        tintTop: Color.white.opacity(0.13),
        tintBottom: Color.white.opacity(0.05),
        sheen: 0.18,
        rimTop: Color.white.opacity(0.50),
        rimBottom: Color.white.opacity(0.08),
        depth: 0.08,
        shadowRadius: 10,
        shadowY: 3,
        shadowOpacity: 0.24
    )
}

private struct GlassFill<S: InsettableShape>: View {
    let shape: S
    let style: GlassStyle

    var body: some View {
        shape
            .fill(Material.ultraThinMaterial)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [style.tintTop, style.tintBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                // 镜面高光：从左上角铺开，边界要软
                shape.fill(
                    RadialGradient(
                        colors: [Color.white.opacity(style.sheen), Color.white.opacity(0)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
            }
            .overlay {
                // 底部厚度：越往下越沉
                shape.fill(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(style.depth)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [style.rimTop, style.rimBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .compositingGroup()
            .shadow(
                color: .black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                y: style.shadowY
            )
    }
}

extension View {
    /// 给任意形状套上液态玻璃底。用法：`.glass(Circle())` / `.glass(cornerRadius: 20)`
    func glass<S: InsettableShape>(_ shape: S, style: GlassStyle = .control) -> some View {
        background { GlassFill(shape: shape, style: style) }
    }

    func glass(cornerRadius: CGFloat, style: GlassStyle = .panel) -> some View {
        glass(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), style: style)
    }
}

// MARK: - 圆形图标按钮

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 36
    var iconSize: CGFloat = 16
    var weight: Font.Weight = .medium
    var style: GlassStyle = .control
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: weight))
                .foregroundStyle(Palette.text)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), style: style)
    }
}
