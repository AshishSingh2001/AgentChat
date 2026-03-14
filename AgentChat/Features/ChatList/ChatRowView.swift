import SwiftUI

struct ChatRowView: View {
    let chat: Chat

    private var draftText: String? {
        UserDefaults.standard.string(forKey: "agentchat.draft.\(chat.id)")
    }

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
            if let draft = draftText, !draft.isEmpty {
                Text("Draft: \(draft)")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            } else {
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
