import Foundation
import SwiftUI
import Photos
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

/// PhotosPicker 拿到的视频：复制到临时目录，避免把整段视频读进内存
struct MovieFile: Transferable {
    let url: URL
    let ext: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty
                ? "mov"
                : received.file.pathExtension.lowercased()
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: received.file, to: temp)
            return MovieFile(url: temp, ext: ext)
        }
    }
}

enum PhotoImporter {
    /// 相册导入：文件名用「日期_流水号」，与素材命名习惯一致
    static func importItems(
        _ items: [PhotosPickerItem],
        into folder: String?,
        library: LibraryStore
    ) async -> Int {
        // 相册默认是「仅选中项」的临时授权，拿不到 PHAsset 就没有原文件名；
        // 第一次导入时申请一次完整访问，用户拒绝也没关系，会回落到日期命名。
        await ensurePhotoAccess()

        let documents = library.documents
        let target = folder.map { documents.appendingPathComponent($0) } ?? documents
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        var saved = 0
        for pickerItem in items {
            guard let movie = try? await pickerItem.loadTransferable(type: MovieFile.self) else { continue }
            // 先按相册里的原文件名存（IMG_0001.MOV），拿不到才用「日期_流水号」
            var name = await originalName(for: pickerItem) ?? nextName(in: target)
            if (name as NSString).pathExtension.isEmpty { name += ".\(movie.ext)" }
            let destination = FileManager.default.uniqueURL(in: target, preferredName: name)
            do {
                try FileManager.default.moveItem(at: movie.url, to: destination)
                saved += 1
            } catch {
                try? FileManager.default.removeItem(at: movie.url)
            }
        }
        if saved > 0 {
            await MainActor.run { library.reload() }
        }
        return saved
    }

    private static func ensurePhotoAccess() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                continuation.resume()
            }
        }
    }

    /// 相册里这条视频的原始文件名。取不到（没给相册权限、或不是来自相册）返回 nil。
    private static func originalName(for item: PhotosPickerItem) async -> String? {
        guard let identifier = item.itemIdentifier,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
        else { return nil }

        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        guard let raw = resource?.originalFilename.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }
        return raw
    }

    private static func nextName(in directory: URL) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let prefix = formatter.string(from: Date())

        var maxIndex = 0
        if let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
            for name in names where name.hasPrefix(prefix + "_") {
                let rest = name.dropFirst(prefix.count + 1)
                let digits = rest.prefix { $0.isNumber }
                if let value = Int(digits) {
                    maxIndex = max(maxIndex, value)
                }
            }
        }
        return String(format: "%@_%03d", prefix, maxIndex + 1)
    }
}
