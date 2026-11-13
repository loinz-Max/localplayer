import SwiftUI
import AVFoundation

@main
struct LocalPlayerApp: App {
    /// 方向锁要靠 AppDelegate 的 supportedInterfaceOrientationsFor 才生效
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var library = LibraryStore()
    @StateObject private var progress = ProgressStore()
    @StateObject private var settings = AppSettings()

    init() {
        #if DEBUG
        // 模拟器截图用：按启动参数生成示例视频
        DebugSeed.runIfNeeded()
        #endif

        // 允许锁屏 / 切后台继续出声
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(progress)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
                // 转屏幕布挂在最外层：进出播放页的转屏发生在黑幕后面
                .overlay { OrientationCurtainView() }
                // 冷启动的品牌一闪（约 1 秒，不拦截触摸）
                .overlay { LaunchFlash() }
                .onAppear {
                    library.reload()
                    OrientationController.shared.restore()
                }
        }
    }
}
