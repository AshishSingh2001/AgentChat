import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let onSend: () -> Void

    @State private var showingImageSourceMenu = false

    private let minHeight: CGFloat = 36
    private let maxHeight: CGFloat = 120

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attachment button
            Button {
                showingImageSourceMenu = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityIdentifier("attachmentButton")
            .confirmationDialog("Add Photo", isPresented: $showingImageSourceMenu) {
                Button("Photo Library") {}
                Button("Camera") {}
                Button("Cancel", role: .cancel) {}
            }

            // Text input
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Message")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $text)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("messageInput")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isSendDisabled ? Color(.systemGray4) : .blue)
            }
            .disabled(isSendDisabled)
            .accessibilityIdentifier("sendButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
