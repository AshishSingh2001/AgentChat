import SwiftUI
import SDWebImageSwiftUI

struct ImageMessageView: View {
    let file: FileAttachment
    let fileStorageService: any FileStorageServiceProtocol
    let caption: String
    let onTap: () -> Void

    private var imageURL: URL? {
        let displayPath = file.thumbnailPath ?? file.path
        if displayPath.hasPrefix("http") {
            return URL(string: displayPath)
        } else {
            return fileStorageService.absoluteURL(for: displayPath)
        }
    }

    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if loadFailed {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Image unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                WebImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 160)
                        ProgressView()
                    }
                }
                .onFailure { _ in loadFailed = true }
                .indicator(.activity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("imageMessage")
                .onTapGesture { onTap() }
            }

            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}
