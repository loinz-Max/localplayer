import SwiftUI

// MARK: - 抽屉外壳

struct PanelShell<Content: View>: View {
    let isLandscape: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let width: CGFloat = isLandscape ? 320 : 264

        Group {
            if isLandscape {
                ScrollView(showsIndicators: false) {
                    content.padding(18)
                }
                .frame(width: width)
                .frame(maxHeight: .infinity)
            } else {
                // 竖屏：高度按内容算，不硬拉到屏幕底
                content.padding(16)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .glass(cornerRadius: 28, style: .panel)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }
}

private struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 0.5)
    }
}

// MARK: - 播放列表抽屉

struct QueuePanel: View {
    let queue: [VideoItem]
    let current: VideoItem
    let isLandscape: Bool
    var onSelect: (VideoItem) -> Void

    @State private var durations: [String: Double] = [:]

    private var index: Int {
        (queue.firstIndex { $0.id == current.id } ?? 0) + 1
    }

    var body: some View {
        PanelShell(isLandscape: isLandscape) {
            VStack(alignment: .leading, spacing: 0) {
                Text("正在播放")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.tertiaryText)

                Text(current.displayName)
                    .font(.system(size: isLandscape ? 18 : 22, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .padding(.top, 6)

                Text(subLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
                    .padding(.top, 4)

                Text("第 \(index) 个 · 共 \(queue.count) 个")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.tertiaryText)
                    .monospacedDigit()
                    .padding(.top, 2)

                PanelDivider().padding(.vertical, 12)

                VStack(spacing: 0) {
                    ForEach(queue) { item in
                        row(item)
                    }
                }
            }
        }
        .task(id: current.id) { await loadDurations() }
    }

    private var subLine: String {
        var parts: [String] = []
        if let duration = durations[current.id] {
            parts.append(Fmt.time(duration))
        }
        parts.append(Fmt.size(current.fileSize))
        return parts.joined(separator: " · ")
    }

    private func row(_ item: VideoItem) -> some View {
        let isCurrent = item.id == current.id
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: 10) {
                // 尺寸必须宽高都给，否则缩略图按自身理想尺寸撑开、盖住右边文字
                ThumbnailView(
                    item: item,
                    cornerRadius: 6,
                    size: CGSize(
                        width: isLandscape ? 60 : 80,
                        height: isLandscape ? 34 : 45
                    )
                )
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Palette.accent, lineWidth: 2)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Palette.text : Palette.text.opacity(0.86))
                        .lineLimit(1)

                    Text(durationText(item))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.tertiaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.vertical, isLandscape ? 4 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func durationText(_ item: VideoItem) -> String {
        if let value = durations[item.id] { return Fmt.time(value) }
        return Fmt.size(item.fileSize)
    }

    private func loadDurations() async {
        for item in queue where durations[item.id] == nil {
            if let value = await ThumbnailLoader.shared.duration(for: item) {
                durations[item.id] = value
            }
        }
    }
}

// MARK: - 倍速面板（浮在倍速键上方的一块小面板）

struct SpeedPanel: View {
    @Binding var rate: Double
    let isLandscape: Bool
    var onPick: () -> Void

    /// 五档够了：2 / 1.5 / 1.25 / 1 / 0.5
    static let rates: [Double] = [2, 1.5, 1.25, 1, 0.5]

    /// 面板按内容算宽：只有「✓ + 1.25 倍」这么点东西，不需要更宽
    private var width: CGFloat { isLandscape ? 116 : 110 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("播放速度")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Palette.tertiaryText)
                .padding(.horizontal, 13)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Self.rates, id: \.self) { value in
                row(value)
            }
        }
        .padding(.bottom, 6)
        .frame(width: width)
        .glass(cornerRadius: 18, style: .panel)
    }

    private func row(_ value: Double) -> some View {
        let active = abs(value - rate) < 0.001
        return Button {
            rate = value
            onPick()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 11)
                    .opacity(active ? 1 : 0)

                Text(Self.label(value))
                    .font(.system(size: 13.5, weight: active ? .semibold : .regular))
                    .monospacedDigit()

                Spacer(minLength: 0)
            }
            .foregroundStyle(active ? Palette.text : Palette.text.opacity(0.86))
            .padding(.horizontal, 13)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    static func label(_ value: Double) -> String {
        value == 1 ? "1 倍" : "\(String(format: "%g", value)) 倍"
    }
}
