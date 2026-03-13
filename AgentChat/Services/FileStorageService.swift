import UIKit

final class FileStorageService: FileStorageServiceProtocol {
    let baseURL: URL

    init(baseURL: URL = FileStorageService.defaultBaseURL) {
        self.baseURL = baseURL
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    static var defaultBaseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentChat/attachments")
    }

    func save(data: Data, filename: String) throws -> String {
        let fileURL = baseURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return filename  // store relative, resolve on display
    }

    func generateThumbnail(from data: Data, maxWidth: CGFloat) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw FileStorageServiceError.invalidImageData
        }

        let newWidth = min(maxWidth, image.size.width)
        let ratio = newWidth / image.size.width
        let newHeight = image.size.height * ratio

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newWidth, height: newHeight), format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        }

        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else {
            throw FileStorageServiceError.failedToGenerateThumbnail
        }

        return jpegData
    }

    func absoluteURL(for filename: String) -> URL {
        baseURL.appendingPathComponent(filename)
    }
}

enum FileStorageServiceError: Error {
    case invalidImageData
    case failedToGenerateThumbnail
}
