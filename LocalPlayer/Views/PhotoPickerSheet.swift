import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 从相册选出来的一段视频：临时文件 + 建议文件名
struct PickedMovie: Identifiable {
    let id = UUID()
    let url: URL
    /// 相册里原本的文件名，例如 IMG_0001.MOV
    let name: String
}

/// 用 PHPickerViewController 而不是 SwiftUI 的 PhotosPicker：
/// 只有前者能拿到 `NSItemProvider.suggestedName`（= 相册里的原文件名），
/// 而且它在独立进程里选片，**不需要相册权限**也不会弹授权框。
struct PhotoPickerSheet: UIViewControllerRepresentable {
    var onPicked: ([PickedMovie]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 0
        // 要原始文件，不要转码后的副本，否则文件名和画质都会变
        config.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPickerSheet

        init(_ parent: PhotoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            let group = DispatchGroup()
            let lock = NSLock()
            var picked: [PickedMovie] = []

            for result in results {
                let provider = result.itemProvider
                guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { continue }

                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    defer { group.leave() }
                    // 这个 url 出了回调就失效，必须当场复制到临时目录
                    guard let url, let copy = Self.stage(url, provider: provider) else { return }
                    lock.lock()
                    picked.append(copy)
                    lock.unlock()
                }
            }

            group.notify(queue: .main) {
                self.parent.onPicked(picked)
            }
        }

        /// 拷到临时目录，并按 suggestedName 取回原名
        private static func stage(_ url: URL, provider: NSItemProvider) -> PickedMovie? {
            var name = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if (name as NSString).pathExtension.isEmpty, !url.pathExtension.isEmpty {
                name = name.isEmpty ? "" : name + "." + url.pathExtension
            }
            if name.isEmpty {
                // 极少数情况下系统不给 suggestedName，退回「视频_时间戳」而不是 UUID 临时名
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let stamp = formatter.string(from: Date())
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                name = "视频_\(stamp).\(ext)"
            }

            let ext = (name as NSString).pathExtension
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext.isEmpty ? url.pathExtension : ext)

            try? FileManager.default.removeItem(at: temp)
            guard (try? FileManager.default.copyItem(at: url, to: temp)) != nil else { return nil }
            return PickedMovie(url: temp, name: name)
        }
    }
}
