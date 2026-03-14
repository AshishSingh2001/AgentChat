import SwiftUI
import SDWebImageSwiftUI

struct ImageMessageView: View {
    let file: FileAttachment
    let fileStorageService: FileStorageService
    let onTap: () -> Void

    private var imageURL: URL? {
        if file.path.hasPrefix("http") {
            return URL(string: file.path)
        } else {
            return fileStorageService.absoluteURL(for: file.path)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .onFailure { _ in }
            .indicator(.activity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { onTap() }

            if file.fileSize > 0 {
                Text(file.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}
