import Foundation
@testable import AgentChat

final class MockFileStorageService: FileStorageServiceProtocol, @unchecked Sendable {
    var savedFiles: [String: Data] = [:]
    var thumbnailData: Data = Data()

    func save(data: Data, filename: String) throws -> String {
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
