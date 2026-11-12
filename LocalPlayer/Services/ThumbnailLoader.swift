import UIKit
import AVFoundation

/// 视频首帧缩略图，带内存缓存。MKV 等系统不支持的容器会失败，UI 侧回落到占位图。
final class ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let durationCache = NSCache<NSString, NSNumber>()
    private var inFlight = Set<String>()
    private var pending: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()

    func cached(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// 卡片副标题要显示时长，这里单独缓存一份，避免每张卡都去解析一次 Asset
    func duration(for item: VideoItem) async -> Double? {
        if let hit = durationCache.object(forKey: item.id as NSString) { return hit.doubleValue }
        guard item.systemPlayable else { return nil }
        let asset = AVURLAsset(url: item.url)
        guard let value = try? await asset.load(.duration) else { return nil }
        let seconds = value.seconds
        guard seconds.isFinite, seconds > 0 else { return nil }
        durationCache.setObject(NSNumber(value: seconds), forKey: item.id as NSString)
        return seconds
    }

    func load(for item: VideoItem, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        if let image = cached(for: item.id) {
            completion(image)
            return
        }
        lock.lock()
        if inFlight.contains(item.id) {
            // 已经有人在生成，挂到同一个等待队列，避免重复解码
            pending[item.id, default: []].append(completion)
            lock.unlock()
            return
        }
        inFlight.insert(item.id)
        lock.unlock()

        guard item.systemPlayable else {
            lock.lock(); inFlight.remove(item.id); lock.unlock()
            completion(nil)
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            let image = await Self.makeImage(for: item, size: size)
            guard let self else { return }

            self.lock.lock()
            self.inFlight.remove(item.id)
            let waiters = self.pending.removeValue(forKey: item.id) ?? []
            self.lock.unlock()

            if let image {
                self.cache.setObject(image, forKey: item.id as NSString)
            }
            await MainActor.run {
                completion(image)
                waiters.forEach { $0(image) }
            }
        }
    }

    /// 取帧点：时长的 12%（不早于 3 秒），避开片头的台标 / 广告 / 黑场。
    /// 失败再依次退到 3 秒与首帧，保证任何能解码的文件都有图。
    private static func makeImage(for item: VideoItem, size: CGSize) async -> UIImage? {
        let asset = AVURLAsset(url: item.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)

        var seconds: Double = 0
        if let duration = try? await asset.load(.duration) {
            seconds = duration.seconds
        }

        var candidates: [Double] = []
        if seconds.isFinite, seconds > 6 {
            candidates.append(min(max(seconds * 0.12, 3), seconds - 1))
        }
        candidates.append(3)
        candidates.append(0)

        for seconds in candidates {
            let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
            if let frame = try? await generator.image(at: time) {
                return UIImage(cgImage: frame.image)
            }
        }
        return nil
    }

    func clear() {
        cache.removeAllObjects()
        durationCache.removeAllObjects()
    }
}
