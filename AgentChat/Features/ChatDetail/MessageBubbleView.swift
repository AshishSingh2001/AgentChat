import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let fileStorageService: FileStorageService

    var isUser: Bool { message.sender == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.type == .file, let file = message.file {
                    ImageMessageView(file: file, fileStorageService: fileStorageService)
                        .frame(maxWidth: 240)
                } else {
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isUser ? Color.blue : Color(.systemGray5))
                        .foregroundStyle(isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text(TimestampFormatter.timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
