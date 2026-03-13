import SwiftUI

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(TimestampFormatter.relativeString(from: chat.lastMessageTimestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(chat.lastMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
