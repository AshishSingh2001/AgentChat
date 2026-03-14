import Foundation

protocol FileStorageServiceProtocol {
    func save(data: Data, filename: String) throws -> String  // returns relative filename
    func generateThumbnail(from data: Data, maxWidth: CGFloat) throws -> Data
    func absoluteURL(for filename: String) -> URL
}
