import SwiftUI

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
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 16) {
                        playbackSection
                        interfaceSection
                        storageSection
                        aboutSection
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
        }
        .preferredColorScheme(.dark)
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
        card(title: "播放") {
            row {
                VStack(alignment: .leading, spacing: 3) {
                    Text("长按倍速")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.onGlass)
                    Text("按住画面时按这个速度播放，松手复原")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onGlassTertiary)
                }
                Spacer()
                Picker("", selection: rateBinding) {
                    ForEach(rates, id: \.self) { rate in
                        Text(rateLabel(rate)).tag(rate)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(Palette.onGlass)
            }

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("默认播放模式")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlass)

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
                    .foregroundStyle(Palette.onGlass)

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
                        .foregroundStyle(Palette.onGlass)
                    Text("再次打开时从上次的位置开始")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onGlassTertiary)
                }
                Spacer()
                Toggle("", isOn: boolBinding(\.resumePlayback))
                    .labelsHidden()
                    .tint(Palette.accent)
            }
        }
    }

    // MARK: - 播放界面

    /// 原来播放页抽屉里的三项，现在统一收在这里
    private var interfaceSection: some View {
        card(title: "播放界面") {
            row {
                VStack(alignment: .leading, spacing: 3) {
                    Text("屏幕常亮")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.onGlass)
                    Text("播放时不自动熄屏")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.onGlassTertiary)
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
                    .foregroundStyle(Palette.onGlass)

                SettingsSegment(
                    titles: autoHideOptions.map { "\(Int($0)) 秒" },
                    selected: autoHideOptions.firstIndex(of: settings.autoHideDelay) ?? 1
                ) { index in
                    settings.autoHideDelay = autoHideOptions[index]
                }
            }
            .padding(.vertical, 4)

            divider

            // 防误触不再预设成"进页面就锁"，改成播放页左下角的手动锁
            VStack(alignment: .leading, spacing: 8) {
                Text("旋转锁定")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlass)

                SettingsSegment(
                    titles: AppSettings.Orientation.allCases.map { $0.title },
                    selected: AppSettings.Orientation.allCases.firstIndex(of: settings.orientationLock) ?? 0
                ) { index in
                    settings.orientationLock = AppSettings.Orientation.allCases[index]
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 存储

    private var storageSection: some View {
        card(title: "存储") {
            row {
                Text("视频占用")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlass)
                Spacer()
                Text(Fmt.size(library.totalSize))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlassSecondary)
                    .monospacedDigit()
            }

            divider

            row {
                Text("视频数量")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlass)
                Spacer()
                Text("\(library.allItems.count)")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlassSecondary)
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
                        .foregroundStyle(Palette.onGlass)
                    Spacer()
                    if cacheCleared {
                        Text("已清理")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.onGlassTertiary)
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
        card(title: "关于") {
            row {
                Text("版本")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlass)
                Spacer()
                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.onGlassSecondary)
            }

            divider

            VStack(alignment: .leading, spacing: 6) {
                Text("本地播放器")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.onGlass)
                Text("视频只存在本机 Documents 目录，不联网、不登录、不上传。用「文件」App 可以直接看到这些文件。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.onGlassSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 小工具

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Palette.tertiaryText)
                .padding(.bottom, 8)

            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .glass(cornerRadius: 18)
        }
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

// MARK: - 设置页里的三段选择

private struct SettingsSegment: View {
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
                        .foregroundStyle(selected == index ? Palette.onGlass : Palette.onGlassSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if selected == index {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.10))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
