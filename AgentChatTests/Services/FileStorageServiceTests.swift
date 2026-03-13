import Testing
import UIKit
@testable import AgentChat

@MainActor
struct FileStorageServiceTests {

    private func makeTempService() -> FileStorageService {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return FileStorageService(baseURL: tempURL)
    }

    // MARK: - Save and File Operations

    @Test func saveWritesFileToExpectedPath() throws {
        let service = makeTempService()
        let testData = Data(count: 10)
        let filename = "test.jpg"

        let result = try service.save(data: testData, filename: filename)
        let fileURL = service.absoluteURL(for: result)

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func saveReturnsRelativeFilename() throws {
        let service = makeTempService()
        let testData = Data(count: 10)
        let filename = "test.jpg"

        let result = try service.save(data: testData, filename: filename)

        #expect(result == filename)
    }

    @Test func saveOverwritesPreviousFile() throws {
        let service = makeTempService()
        let filename = "test.jpg"
        let firstData = "aaa".data(using: .utf8)!
        let secondData = "bbb".data(using: .utf8)!

        _ = try service.save(data: firstData, filename: filename)
        _ = try service.save(data: secondData, filename: filename)

        let fileURL = service.absoluteURL(for: filename)
        let readData = try Data(contentsOf: fileURL)

        #expect(readData == secondData)
    }

    // MARK: - Thumbnail Generation

    @Test func generateThumbnailProducesImageSmallerThanMaxWidth() throws {
        let service = makeTempService()

        // Create a 400x300 UIImage
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let jpegData = image.jpegData(compressionQuality: 0.8)!
        let thumbnailData = try service.generateThumbnail(from: jpegData, maxWidth: 150)
        let thumbnailImage = UIImage(data: thumbnailData)

        #expect(thumbnailImage != nil)
        #expect(thumbnailImage!.size.width <= 150)
    }

    // MARK: - URL Resolution

    @Test func absoluteURLResolvesToBaseURL() throws {
        let service = makeTempService()
        let filename = "img.jpg"

        let absoluteURL = service.absoluteURL(for: filename)

        #expect(absoluteURL.path.contains(service.baseURL.path))
    }
}
