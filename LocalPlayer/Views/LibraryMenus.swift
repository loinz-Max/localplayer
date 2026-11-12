import SwiftUI

// MARK: - 通用行

struct MenuRowButton: View {
    let title: String
    var icon: String? = nil
    var checked: Bool = false
    var danger: Bool = false
    var height: CGFloat = 44
    var fontSize: CGFloat = 15.5
    var iconWidth: CGFloat = 20
    var horizontalPadding: CGFloat = 13
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Group {
                    if let icon {
                        Image(systemName: checked ? "checkmark" : icon)
                            .font(.system(size: 15, weight: .medium))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: iconWidth, alignment: .center)

                Text(title)
                    .font(.system(size: fontSize))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(danger ? Palette.danger : Palette.text)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 白色圆底 + 深色符号（导入菜单专用，和 Outplayer 一致）
struct MenuBadgeRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white))

                Text(title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MenuSeparator: View {
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 4

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }
}

// MARK: - 菜单容器

struct GlassMenuContainer<Content: View>: View {
    var width: CGFloat = 200
    var cornerRadius: CGFloat = 20
    var verticalPadding: CGFloat = 4
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(width: width)
            .padding(.vertical, verticalPadding)
            .glass(cornerRadius: cornerRadius, style: .panel)
    }
}

// MARK: - 导入菜单

struct ImportMenu: View {
    var onPhoto: () -> Void
    var onFile: () -> Void

    var body: some View {
        GlassMenuContainer(width: 200, verticalPadding: 4) {
            MenuBadgeRow(title: "从相册导入", icon: "photo", action: onPhoto)
            MenuBadgeRow(title: "从文件导入", icon: "folder", action: onFile)
        }
    }
}

// MARK: - 「…」菜单

struct MoreMenu: View {
    let viewMode: AppSettings.LibraryView
    let sortKey: SortKey
    let ascending: Bool
    var onSelectAll: () -> Void
    var onCreateFolder: () -> Void
    var onViewMode: (AppSettings.LibraryView) -> Void
    var onNameSort: () -> Void
    var onDateSort: () -> Void

    static let width: CGFloat = 210

    var body: some View {
        GlassMenuContainer(width: Self.width) {
            MenuRowButton(title: "全选", icon: "checkmark.circle", action: onSelectAll)
            MenuRowButton(title: "创建文件夹", icon: "folder.badge.plus", action: onCreateFolder)

            MenuSeparator()

            MenuRowButton(
                title: "网格",
                icon: viewMode == .grid ? "checkmark" : nil,
                action: { onViewMode(.grid) }
            )
            MenuRowButton(
                title: "列表",
                icon: viewMode == .list ? "checkmark" : nil,
                action: { onViewMode(.list) }
            )

            MenuSeparator()

            // 名称：已经在按名称排序时点一下就是升/降切换
            MenuRowButton(
                title: nameTitle,
                icon: sortKey == .name ? "checkmark" : nil,
                action: onNameSort
            )
            MenuRowButton(
                title: "日期",
                icon: sortKey == .added ? "checkmark" : nil,
                action: onDateSort
            )

            Color.clear.frame(height: 4)
        }
    }

    private var nameTitle: String {
        guard sortKey == .name else { return "名称" }
        return ascending ? "名称 ↑" : "名称 ↓"
    }
}

// MARK: - 长按菜单（锚定卡片）

struct CardMenu: View {
    let item: VideoItem
    let watched: Bool
    var onMarkWatched: () -> Void
    var onRename: () -> Void
    var onMove: () -> Void
    var onDelete: () -> Void

    static let width: CGFloat = 174
    static let estimatedHeight: CGFloat = 216

    var body: some View {
        VStack(spacing: 0) {
            Text(item.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.text.opacity(0.70))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 7)

            MenuSeparator(horizontalPadding: 10, verticalPadding: 3)

            MenuRowButton(
                title: watched ? "标记为未看" : "标记为已看",
                icon: watched ? "circle" : "checkmark.circle",
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onMarkWatched
            )
            MenuRowButton(
                title: "重命名",
                icon: "pencil",
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onRename
            )
            MenuRowButton(
                title: "移到文件夹",
                icon: "folder",
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onMove
            )

            MenuSeparator(horizontalPadding: 10, verticalPadding: 3)

            MenuRowButton(
                title: "删除",
                icon: "trash",
                danger: true,
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onDelete
            )
        }
        .frame(width: Self.width)
        .padding(.vertical, 3)
        .glass(cornerRadius: 18, style: .panel)
    }
}

// MARK: - 文件夹长按菜单

struct FolderMenu: View {
    let name: String
    var onRename: () -> Void
    var onDelete: () -> Void

    static let width: CGFloat = 174
    static let estimatedHeight: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            Text(name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Palette.text.opacity(0.70))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 7)

            MenuSeparator(horizontalPadding: 10, verticalPadding: 3)

            MenuRowButton(
                title: "重命名",
                icon: "pencil",
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onRename
            )
            MenuRowButton(
                title: "删除文件夹",
                icon: "trash",
                danger: true,
                height: 42,
                fontSize: 15,
                iconWidth: 19,
                horizontalPadding: 12,
                action: onDelete
            )
        }
        .frame(width: Self.width)
        .padding(.vertical, 3)
        .glass(cornerRadius: 18, style: .panel)
    }
}

// MARK: - 选择目标文件夹

struct MoveFolderSheet: View {
    /// 顶部那行小字：单个文件是文件名，批量是「已选 N 个视频」
    let subtitle: String
    /// 这些文件当前所在的目录，用来把那一条置灰
    let currentFolder: String
    let choices: [FolderChoice]
    var onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("移到文件夹")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("取消") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)

                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(choices) { choice in
                            row(choice)
                            Rectangle()
                                .fill(Palette.hairline)
                                .frame(height: 0.5)
                                .padding(.leading, 16 + CGFloat(choice.depth) * 14)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .glass(cornerRadius: 18)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // 系统 sheet 默认带材质，近黑配色下会透出底下的网格，这里铺一层实色
        .presentationBackground(Palette.background)
    }

    private func row(_ choice: FolderChoice) -> some View {
        let isCurrent = choice.path == currentFolder
        return Button {
            onPick(choice.path)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: choice.path.isEmpty ? "tray.full" : "folder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isCurrent ? Palette.tertiaryText : Palette.accent)
                    .frame(width: 20)

                Text(choice.display)
                    .font(.system(size: 14))
                    .foregroundStyle(isCurrent ? Palette.tertiaryText : Palette.text)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isCurrent {
                    Text("当前")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.tertiaryText)
                }
            }
            .padding(.leading, CGFloat(choice.depth) * 14)
            .padding(.horizontal, 4)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
}
