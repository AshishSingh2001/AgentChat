import Foundation

@Observable
@MainActor
final class ImageViewerViewModel {
    var selectedImageURL: URL?

    func open(url: URL) {
        selectedImageURL = url
    }

    func dismiss() {
        selectedImageURL = nil
    }
}
