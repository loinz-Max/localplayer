import SwiftUI

/// 轻提示的统一外观：胶囊 + 可选小图标 + 一行字。
///
/// 播放页的长按倍速、两侧导入的 toast 都用它，避免每处各写一套 padding 和字号。
/// 数字一律等宽，倍速从 2× 变 10× 时胶囊不会左右跳。
struct HUDLabel: View {
    let text: String
    /// 跟在主文案后面的小字，例如「2× 快进」里的「快进」
    var detail: String?
    var icon: String?
    var iconSize: CGFloat = 10.5
    var fontSize: CGFloat = 13
    var weight: Font.Weight = .medium

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
            }
            Text(text)
                .font(.system(size: fontSize, weight: weight))
                .monospacedDigit()
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.system(size: fontSize - 1.5, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glass(Capsule(), style: .hud)
    }
}

/// 导入进度：胶囊里一行「正在导入 3/8」，底下一条跟着长的细线。
/// 不用全屏遮罩，导入期间照样能滑动、能点开别的视频。
struct ImportProgressHUD: View {
    let progress: ImportProgress

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10.5, weight: .bold))

                Text("正在导入")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.secondaryText)

                Text("\(progress.done)/\(progress.total)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(Palette.text)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(3, geo.size.width * progress.fraction))
                }
            }
            .frame(height: 2.5)
            .animation(.easeOut(duration: 0.18), value: progress.done)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: 166)
        .glass(cornerRadius: 15, style: .hud)
        .allowsHitTesting(false)
    }
}
