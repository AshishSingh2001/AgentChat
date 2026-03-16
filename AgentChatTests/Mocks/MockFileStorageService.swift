import Foundation
@testable import AgentChat

final class MockFileStorageService: FileStorageServiceProtocol, @unchecked Sendable {
    var savedFiles: [String: Data] = [:]
    var thumbnailData: Data = Data()
    var shouldThrowOnSave: Error?

    func save(data: Data, filename: String) throws -> String {
        if let error = shouldThrowOnSave { throw error }
        savedFiles[filename] = data
        return filename
    }

    func generateThumbnail(from data: Data, maxWidth: CGFloat) throws -> Data {
        thumbnailData
    }

    func absoluteURL(for filename: String) -> URL {
        URL(fileURLWithPath: "/mock/\(filename)")
    }
}
