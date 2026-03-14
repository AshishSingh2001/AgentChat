import SwiftUI
import SDWebImageSwiftUI

struct ImageMessageView: View {
    let file: FileAttachment
    let fileStorageService: any FileStorageServiceProtocol
    let onTap: () -> Void

    private var imageURL: URL? {
        if file.path.hasPrefix("http") {
            return URL(string: file.path)
        } else {
            return fileStorageService.absoluteURL(for: file.path)
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
                .onTapGesture { onTap() }
            }

            if file.fileSize > 0 {
                Text(file.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}
