import SwiftUI

/// 白色液态玻璃配方。
///
/// 关键点：`Material` 的明暗跟着 `colorScheme` 走。App 是深色界面，
/// 直接用 `.ultraThinMaterial` 渲染出来是一层**灰**——这就是「灰质」的根源。
/// 这里给材质单独注入 `colorScheme = .light`，强制它走浅色雾面，
/// 深背景透上来才会变成白雾。
///
/// 注意别再改回 `UIViewRepresentable` 包 `UIVisualEffectView`：那是真正的
/// UIView 子视图，会盖在同一层 SwiftUI 画的白色染色之上，染色等于没加。
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
    var material: Material = .ultraThinMaterial

    /// 资料库这类深色底上的圆键、胶囊
    static let control = GlassStyle(
        tintTop: Color.white.opacity(0.72),
        tintBottom: Color.white.opacity(0.46),
        sheen: 0.90,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.55),
        depth: 0.00,
        shadowRadius: 12,
        shadowY: 4,
        shadowOpacity: 0.22,
        material: .ultraThinMaterial
    )

    /// 菜单、抽屉、弹窗：要压住内容，材质取厚一点
    static let panel = GlassStyle(
        tintTop: Color.white.opacity(0.68),
        tintBottom: Color.white.opacity(0.44),
        sheen: 0.80,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.50),
        depth: 0.02,
        shadowRadius: 26,
        shadowY: 10,
        shadowOpacity: 0.30,
        material: .thinMaterial
    )

    /// 播放页：压在视频画面上，同样的白玻璃，但要更实一点才压得住亮画面
    static let stage = GlassStyle(
        tintTop: Color.white.opacity(0.70),
        tintBottom: Color.white.opacity(0.46),
        sheen: 0.82,
        rimTop: Color.white.opacity(1.0),
        rimBottom: Color.white.opacity(0.50),
        depth: 0.02,
        shadowRadius: 14,
        shadowY: 5,
        shadowOpacity: 0.26,
        material: .ultraThinMaterial
    )

    /// 更淡一档，用于进度条这类大面积浅底
    static let subtle = GlassStyle(
        tintTop: Color.white.opacity(0.44),
        tintBottom: Color.white.opacity(0.24),
        sheen: 0.66,
        rimTop: Color.white.opacity(0.94),
        rimBottom: Color.white.opacity(0.30),
        depth: 0.00,
        shadowRadius: 10,
        shadowY: 3,
        shadowOpacity: 0.20
    )
}

private struct GlassFill<S: InsettableShape>: View {
    let shape: S
    let style: GlassStyle

    var body: some View {
        ZStack {
            // 1. 浅色雾化：Material 的明暗跟着 colorScheme 走，强制 light 才有白雾
            shape.fill(style.material)
                .environment(\.colorScheme, .light)

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
