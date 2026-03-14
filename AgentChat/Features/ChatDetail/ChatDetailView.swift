import SwiftUI

struct ChatDetailView: View {
    @State private var viewModel: ChatDetailViewModel

    init(
        chatId: String,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        fileStorageService: FileStorageService
    ) {
        _viewModel = State(initialValue: ChatDetailViewModel(
            chatId: chatId,
            chatRepository: chatRepository,
            messageRepository: messageRepository,
            router: router,
            fileStorageService: fileStorageService
        ))
    }

    var body: some View {
        @Bindable var vm = viewModel
        let title = viewModel.displayTitle
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, fileStorageService: viewModel.fileStorageService)
            InputBarView(
                text: $vm.draftText,
                onSend: {
                    Task { await viewModel.sendMessage(text: viewModel.draftText) }
                },
                onAttachmentPicked: { data, image in
                    viewModel.setPendingAttachment(PendingAttachment(data: data, previewImage: image))
                },
                onSendWithAttachment: {
                    Task { await viewModel.sendWithAttachment() }
                },
                pendingAttachment: viewModel.pendingAttachment,
                onClearAttachment: {
                    viewModel.clearPendingAttachment()
                }
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    viewModel.startTitleEdit()
                } label: {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $vm.isTitleEditing) {
            TitleEditSheet(
                title: viewModel.chat.title,
                onCommit: { newTitle in
                    Task { await viewModel.commitTitleEdit(newTitle: newTitle) }
                }
            )
            .presentationDetents([.height(160)])
        }
        .fullScreenCover(item: $vm.selectedImageForViewer) { item in
            ImageViewerView(item: item) {
                viewModel.dismissImageViewer()
            }
        }
        .onDisappear {
            viewModel.saveDraftImmediately()
        }
        .task {
            await viewModel.loadMessages()
        }
    }
}

private struct TitleEditSheet: View {
    @State private var editedTitle: String
    @Environment(\.dismiss) private var dismiss
    let onCommit: (String) -> Void

    init(title: String, onCommit: @escaping (String) -> Void) {
        _editedTitle = State(initialValue: title)
        self.onCommit = onCommit
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Chat title", text: $editedTitle)
            }
            .navigationTitle("Rename Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onCommit(editedTitle)
                        dismiss()
                    }
                }
            }
        }
    }
}
