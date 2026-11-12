import AVFoundation
import UIKit

/// 拖动进度时的小窗预览帧。
///
/// 拖动时 `onChanged` 每秒能触发几十次，每次都去解码会直接把主线程拖卡，
/// 所以这里做两件事：按 0.5 秒一档缓存，且同一时刻只允许一个抓帧任务在跑。
@MainActor
final class ScrubPreviewer {
    static let shared = ScrubPreviewer()

    private var generator: AVAssetImageGenerator?
    private var url: URL?
    private var lastRequestedAt: Double = -100
    private var busy = false
    private var cache: [Int: UIImage] = [:]

    /// 切集时调用：换 generator、清缓存
    func prepare(for url: URL) {
        guard self.url != url else { return }
        self.url = url

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 202)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        self.generator = generator

        cache.removeAll()
        lastRequestedAt = -100
    }

    /// 取某一秒的画面。时间没跳够、或上一帧还没出来时返回 nil（调用方保留旧图）。
    func image(at seconds: Double) async -> UIImage? {
        let key = Int((seconds * 2).rounded())
        if let hit = cache[key] { return hit }

        guard let generator, !busy, abs(seconds - lastRequestedAt) > 0.25 else { return nil }

        busy = true
        lastRequestedAt = seconds
        defer { busy = false }

        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        guard let frame = try? await generator.image(at: time) else { return nil }

        let image = UIImage(cgImage: frame.image)
        if cache.count > 80 { cache.removeAll() }
        cache[key] = image
        return image
    }
}
