import Foundation
import SwiftUI

/// 相册导入：文件在 PhotoPickerSheet 里已经落到临时目录并带上了原名，这里只负责搬进 Documents
enum PhotoImporter {
    /// 返回成功导入的数量
    static func importFiles(_ movies: [PickedMovie], into folder: String?, library: LibraryStore) async -> Int {
        let documents = library.documents
        let target = folder.map { documents.appendingPathComponent($0) } ?? documents
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        var saved = 0
        for movie in movies {
            let destination = FileManager.default.uniqueURL(in: target, preferredName: movie.name)
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
}
