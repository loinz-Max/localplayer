import SwiftUI

/// 设置的一级菜单
enum SettingsPage: String, Hashable, CaseIterable, Identifiable {
    case playback, interface, storage, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playback: return "播放"
        case .interface: return "播放界面"
        case .storage: return "存储"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .playback: return "play.circle"
        case .interface: return "rectangle.on.rectangle"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var cacheCleared = false

    /// 长按时的倍速档位
    private let rates: [Double] = [1.5, 2, 2.5, 3]
    private let gravityTitles = ["适应", "填充", "拉伸"]
    private let autoHideOptions: [Double] = [2, 4, 6]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 16) {
                            menuCard
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsPage.self) { page in
                detail(page)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 一级菜单

    private var menuCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(SettingsPage.allCases.enumerated()), id: \.element.id) { index, page in
                if index > 0 { divider }

                NavigationLink(value: page) {
                    HStack(spacing: 12) {
                        Image(systemName: page.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 24)

                        Text(page.title)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.text)

                        Spacer(minLength: 8)

                        Text(summary(for: page))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(1)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.tertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .glass(cornerRadius: 18)
    }

    /// 一级菜单右侧那句摘要：不进二级页也能看到关键状态
    private func summary(for page: SettingsPage) -> String {
        switch page {
        case .playback:
            let rate = String(format: "%g", settings.longPressRate)
            return "长按 \(rate)× · \(settings.resumePlayback ? "续播开" : "续播关")"
        case .interface:
            return "\(settings.orientationLock.title) · 常亮\(settings.keepAwake ? "开" : "关")"
        case .storage:
            return Fmt.size(library.totalSize)
        case .about:
            return appVersion
        }
    }

    // MARK: - 二级页

    private func detail(_ page: SettingsPage) -> some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                detailHeader(page.title)

                ScrollView {
                    VStack(spacing: 16) {
                        switch page {
                        case .playback: playbackSection
                        case .interface: interfaceSection
                        case .storage: storageSection
                        case .about: aboutSection
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
        }
    }

    private func detailHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            BackButton()

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.text)

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 54)
    }

    // MARK: - 头

    private var header: some View {
        HStack {
            Text("设置")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.text)

            Spacer()

            Button("完成") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: - 播放

    private var playbackSection: some View {
        card {
            row {
                VStack(alignment: .leading, spacing: 3) {
                    Text("长按倍速")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                    Text("按住画面时按这个速度播放，松手复原")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.tertiaryText)
                }
                Spacer()
                Picker("", selection: rateBinding) {
                    ForEach(rates, id: \.self) { rate in
                        Text(rateLabel(rate)).tag(rate)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(Palette.text)
            }

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("默认播放模式")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)

                SettingsSegment(
                    titles: PlayMode.allCases.map(\.title),
                    selected: PlayMode.allCases.firstIndex(of: settings.defaultPlayMode) ?? 0
                ) { index in
                    settings.defaultPlayMode = PlayMode.allCases[index]
                }
            }
            .padding(.vertical, 4)

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("默认画面")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)

                SettingsSegment(
                    titles: gravityTitles,
                    selected: min(max(settings.defaultGravity, 0), gravityTitles.count - 1)
                ) { index in
                    settings.defaultGravity = index
                }
            }
            .padding(.vertical, 4)

            divider

            row {
                VStack(alignment: .leading, spacing: 3) {
                    Text("断点续播")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                    Text("再次打开时从上次的位置开始")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.tertiaryText)
                }
                Spacer()
                Toggle("", isOn: boolBinding(\.resumePlayback))
                    .labelsHidden()
                    .tint(Palette.accent)
            }
        }
    }

    // MARK: - 播放界面

    private var interfaceSection: some View {
        card {
            row {
                VStack(alignment: .leading, spacing: 3) {
                    Text("屏幕常亮")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                    Text("播放时不自动熄屏")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.tertiaryText)
                }
                Spacer()
                Toggle("", isOn: boolBinding(\.keepAwake))
                    .labelsHidden()
                    .tint(Palette.accent)
            }

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("控件自动隐藏")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)

                SettingsSegment(
                    titles: autoHideOptions.map { "\(Int($0)) 秒" },
                    selected: autoHideOptions.firstIndex(of: settings.autoHideDelay) ?? 1
                ) { index in
                    settings.autoHideDelay = autoHideOptions[index]
                }
            }
            .padding(.vertical, 4)

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("旋转锁定")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)

                SettingsSegment(
                    titles: AppSettings.Orientation.allCases.map { $0.title },
                    selected: AppSettings.Orientation.allCases.firstIndex(of: settings.orientationLock) ?? 0
                ) { index in
                    settings.orientationLock = AppSettings.Orientation.allCases[index]
                }
            }
            .padding(.vertical, 4)

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("资料库排版")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)

                SettingsSegment(
                    titles: AppSettings.LibraryView.allCases.map { $0.title },
                    selected: AppSettings.LibraryView.allCases.firstIndex(of: settings.libraryView) ?? 0
                ) { index in
                    settings.libraryView = AppSettings.LibraryView.allCases[index]
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 存储

    private var storageSection: some View {
        card {
            row {
                Text("视频占用")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(Fmt.size(library.totalSize))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
            }

            divider

            row {
                Text("视频数量")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(library.allItems.count)")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
            }

            divider

            Button {
                ThumbnailLoader.shared.clear()
                library.reload()
                cacheCleared = true
            } label: {
                HStack {
                    Text("清理缩略图缓存")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    if cacheCleared {
                        Text("已清理")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.tertiaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 44)
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        card {
            row {
                Text("版本")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.secondaryText)
            }

            divider

            VStack(alignment: .leading, spacing: 6) {
                Text("本地播放器")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text("视频只存在本机 Documents 目录，不联网、不登录、不上传。用「文件」App 可以直接看到这些文件。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 小工具

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .glass(cornerRadius: 18)
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .frame(height: 46)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }

    private func boolBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    private var rateBinding: Binding<Double> {
        Binding(
            get: { settings.longPressRate },
            set: { settings.longPressRate = $0 }
        )
    }

    private func rateLabel(_ value: Double) -> String {
        "\(String(format: "%g", value))×"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - 返回键

/// NavigateStack 里自绘的返回按钮（系统导航栏被隐藏了）
private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分段控件

struct SettingsSegment: View {
    let titles: [String]
    let selected: Int
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(titles[index])
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(selected == index ? Palette.text : Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if selected == index {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.16))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
}
