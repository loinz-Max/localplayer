import SwiftUI

// MARK: - 缩略图

struct ThumbnailView: View {
    let item: VideoItem
    var cornerRadius: CGFloat = 12
    /// 给了尺寸就严格按这个尺寸裁切（抽屉里的小图）；不给则铺满父级并保持 16:9
    var size: CGSize? = nil

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.07))
            if let image {
                // 用 fit 不用 fill：竖屏 / 4:3 片源只补边，不把两侧画面裁掉
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: item.systemPlayable ? "film" : "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Palette.tertiaryText)
            }
        }
        .modifier(ThumbnailFrame(size: size))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            // 统一按 640×360 生成一次，网格和抽屉共用同一份缓存
            ThumbnailLoader.shared.load(for: item, size: CGSize(width: 640, height: 360)) { loaded in
                image = loaded
            }
        }
    }
}

/// 尺寸约束：有明确尺寸就锁定，没有则撑满父级、按 16:9 收口。
/// clipped() 必须在 clipShape 之前，否则图片会跑出圆角矩形（穿模）。
private struct ThumbnailFrame: ViewModifier {
    let size: CGSize?

    func body(content: Content) -> some View {
        if let size {
            content
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            content
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipped()
        }
    }
}

// MARK: - 缩略图底部细进度条

private struct CardProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.22))
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: max(0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - 右下角已看角标

struct WatchedBadge: View {
    var active: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(active ? Color(red: 0.08, green: 0.09, blue: 0.10) : Color.white)
            .frame(width: 22, height: 22)
            .background {
                Circle()
                    .fill(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(Material.ultraThinMaterial))
                    .overlay {
                        Circle().fill(active ? Color.clear : Color.black.opacity(0.34))
                    }
                    .overlay {
                        Circle().strokeBorder(
                            Color.white.opacity(active ? 0 : 0.42),
                            lineWidth: 0.75
                        )
                    }
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
            }
    }
}

// MARK: - 右下角进度角标

/// 看了一半的片子：右下角直接给百分比，比一条细线更好判断
struct ProgressBadge: View {
    let fraction: Double

    var body: some View {
        Text("\(Int((min(max(fraction, 0), 1) * 100).rounded()))%")
            .font(.system(size: 10.5, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.58))
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.26), lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - 网格卡片

struct VideoCard: View {
    let item: VideoItem
    let fraction: Double
    var watched: Bool = false
    /// 长按选中时角标变实心白底
    var active: Bool = false
    /// 多选模式下被选中
    var selected: Bool = false
    /// 搜索结果里显示所在文件夹（平时为 nil）
    var folderName: String? = nil
    /// 长按浮起的那一份：加一层投影，做出「离开网格」的层次
    var lifted: Bool = false

    @State private var duration: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThumbnailView(item: item)
                .overlay(alignment: .bottom) {
                    if fraction > 0.01, !watched {
                        CardProgressBar(fraction: fraction)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if watched || active {
                        WatchedBadge(active: active)
                            .padding(8)
                    } else if fraction > 0.01 {
                        ProgressBadge(fraction: fraction)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white, Palette.accent)
                            .padding(8)
                    }
                }
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.accent, lineWidth: 2)
                    }
                }
                .compositingGroup()
                .shadow(
                    color: .black.opacity(lifted ? 0.45 : 0),
                    radius: lifted ? 16 : 0,
                    y: lifted ? 9 : 0
                )

            Text(item.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.top, 9)

            Text(metaText)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
        .task(id: item.id) {
            duration = await ThumbnailLoader.shared.duration(for: item)
        }
    }

    private var metaText: String {
        var parts: [String] = []
        if let folderName, !folderName.isEmpty {
            parts.append(folderName)
        }
        if let duration, duration > 0 {
            parts.append(Fmt.time(duration))
        }
        parts.append(Fmt.size(item.fileSize))
        return parts.joined(separator: " · ")
    }
}

// MARK: - 文件夹卡片

struct FolderCard: View {
    let name: String
    let count: Int
    /// 长按浮起的那一份：加一层投影，做出「离开网格」的层次
    var lifted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                Image(systemName: "folder.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Palette.accent.opacity(0.9))
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .compositingGroup()
            .shadow(
                color: .black.opacity(lifted ? 0.45 : 0),
                radius: lifted ? 16 : 0,
                y: lifted ? 9 : 0
            )

            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .padding(.top, 9)

            Text("\(count) 个视频")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.secondaryText)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }
}


// MARK: - 列表行

struct VideoRow: View {
    let item: VideoItem
    let fraction: Double
    var watched: Bool = false
    var selected: Bool = false
    /// 搜索结果里显示所在文件夹（平时为 nil）
    var folderName: String? = nil

    @State private var duration: Double?

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(item: item, cornerRadius: 8, size: CGSize(width: 96, height: 54))
                .overlay(alignment: .bottom) {
                    if fraction > 0.01, !watched {
                        CardProgressBar(fraction: fraction)
                    }
                }
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Palette.accent, lineWidth: 2)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(metaText)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white, Palette.accent)
            } else if watched {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.tertiaryText)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .task(id: item.id) {
            duration = await ThumbnailLoader.shared.duration(for: item)
        }
    }

    private var metaText: String {
        var parts: [String] = []
        if let folderName, !folderName.isEmpty {
            parts.append(folderName)
        }
        if let duration, duration > 0 {
            parts.append(Fmt.time(duration))
        }
        parts.append(Fmt.size(item.fileSize))
        if fraction > 0.01, !watched {
            parts.append("已看 \(Int((min(max(fraction, 0), 1) * 100).rounded()))%")
        }
        return parts.joined(separator: " · ")
    }
}
