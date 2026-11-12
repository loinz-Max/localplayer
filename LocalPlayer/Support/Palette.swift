import SwiftUI

/// 界面色板。数值与 preview/ui-v3.html 的 :root 一一对应，改这里等于改原型。
enum Palette {
    /// #0A0A0B
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255)

    /// 系统蓝 #0A84FF
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)

    /// #EBEBF0
    static let text = Color(red: 235 / 255, green: 235 / 255, blue: 240 / 255)
    /// rgba(235,235,240,.58)
    static let secondaryText = text.opacity(0.58)
    /// rgba(235,235,240,.34)
    static let tertiaryText = text.opacity(0.34)

    /// #FF453A
    static let danger = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)

    /// 分隔线：rgba(255,255,255,.10)
    static let hairline = Color.white.opacity(0.10)

    /// 菜单里那一层极淡的选中底色
    static let rowHighlight = Color.white.opacity(0.08)

    // MARK: - 白玻璃上的内容色
    //
    // 玻璃本身是白色雾面，上面必须用深色字/图标，否则白字贴白底等于没有。
    // 只有"不在玻璃上"的东西（页面标题、卡片标题）继续用上面的 text。

    /// #141416
    static let onGlass = Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255)
    /// rgba(20,20,22,.56)
    static let onGlassSecondary = onGlass.opacity(0.56)
    /// rgba(20,20,22,.40)
    static let onGlassTertiary = onGlass.opacity(0.40)

    /// 白玻璃内部的分隔线：rgba(0,0,0,.10)
    static let glassHairline = Color.black.opacity(0.10)
    /// 白玻璃内部控件（进度条轨道、缩略图占位）
    static let glassTrack = Color.black.opacity(0.14)
}
