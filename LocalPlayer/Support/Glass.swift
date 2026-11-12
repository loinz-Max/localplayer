import SwiftUI
import UIKit

/// 白色液态玻璃配方。
///
/// 关键点：`Material` 会跟随系统深浅色走，App 是深色界面，所以
/// `.ultraThinMaterial` 渲染出来是一层**灰**——这就是「灰质」的根源，
/// 后面叠多少白色染色都压不回来。
///
/// 这里改用 `UIVisualEffectView` + `systemUltraThinMaterialLight`：
/// 强制浅色雾化材质，深色背景透上来会被提亮成白色磨砂，才是真正的白玻璃。
///
/// 层序：
///   1. 浅色雾化材质 —— 背景被模糊并提亮成白雾
///   2. 白色染色 —— 顶部接近纯白、底部只到四成，这条明暗差就是玻璃的"弧面"
///      （均匀加白在纯黑底上只会得到一块灰，必须有这个差才像玻璃）
///   3. 左上镜面高光 —— 让平面看起来是凸的
///   4. 底部厚度 —— 极淡的暗边，制造玻璃体感（白玻璃只要一点点）
///   5. 边缘光 —— 上沿接近纯白、下沿半透，1pt 渐变描边
///   6. 内圈细高光 —— 玻璃断面的厚度
///   7. 外投影 —— 浮在背景之上
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
    var blur: UIBlurEffect.Style = .systemUltraThinMaterialLight

    /// 资料库这类深色底上的圆键、胶囊
    static let control = GlassStyle(
        tintTop: Color.white.opacity(0.90),
        tintBottom: Color.white.opacity(0.38),
        sheen: 0.85,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.42),
        depth: 0.00,
        shadowRadius: 12,
        shadowY: 4,
        shadowOpacity: 0.22,
        blur: .systemThinMaterialLight
    )

    /// 菜单、抽屉、弹窗：要压住内容，材质取厚一点
    static let panel = GlassStyle(
        tintTop: Color.white.opacity(0.82),
        tintBottom: Color.white.opacity(0.42),
        sheen: 0.72,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.38),
        depth: 0.02,
        shadowRadius: 26,
        shadowY: 10,
        shadowOpacity: 0.30,
        blur: .systemThinMaterialLight
    )

    /// 播放页：压在视频画面上，同样的白玻璃，但要更实一点才压得住亮画面
    static let stage = GlassStyle(
        tintTop: Color.white.opacity(0.86),
        tintBottom: Color.white.opacity(0.44),
        sheen: 0.76,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.38),
        depth: 0.02,
        shadowRadius: 14,
        shadowY: 5,
        shadowOpacity: 0.26,
        blur: .systemThinMaterialLight
    )

    /// 更淡一档，用于进度条这类大面积浅底
    static let subtle = GlassStyle(
        tintTop: Color.white.opacity(0.62),
        tintBottom: Color.white.opacity(0.24),
        sheen: 0.62,
        rimTop: Color.white.opacity(0.94),
        rimBottom: Color.white.opacity(0.30),
        depth: 0.00,
        shadowRadius: 10,
        shadowY: 3,
        shadowOpacity: 0.20
    )
}

// MARK: - 浅色雾化底

private struct LightBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

private struct GlassFill<S: InsettableShape>: View {
    let shape: S
    let style: GlassStyle

    var body: some View {
        ZStack {
            // 1. 浅色雾化：深背景透上来变白雾，这是"白玻璃"和"灰块"的分界
            LightBlur(style: style.blur)

            // 2. 白色染色
            shape.fill(
                LinearGradient(
                    colors: [style.tintTop, style.tintBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // 3. 左上镜面高光
            shape.fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(style.sheen),
                        Color.white.opacity(style.sheen * 0.34),
                        Color.white.opacity(0)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 120
                )
            )

            // 4. 底部厚度
            shape.fill(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(style.depth)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(shape)
        .overlay {
            // 5. 边缘光：上沿接近纯白，是液态玻璃最好认的特征
            shape.strokeBorder(
                LinearGradient(
                    colors: [style.rimTop, style.rimBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .overlay {
            // 6. 内圈细高光：玻璃断面的厚度
            shape
                .inset(by: 1.1)
                .strokeBorder(Color.white.opacity(0.55 + style.sheen * 0.3), lineWidth: 0.5)
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
                .foregroundStyle(Palette.onGlass)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), style: style)
    }
}
