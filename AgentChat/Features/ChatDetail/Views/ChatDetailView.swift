import SwiftUI

struct ChatDetailView: View {
    @State private var viewModel: ChatDetailViewModel
    let fileStorageService: any FileStorageServiceProtocol

    init(
        chat: Chat,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        fileStorageService: any FileStorageServiceProtocol,
        agentService: any AgentServiceProtocol
    ) {
        self.fileStorageService = fileStorageService
        _viewModel = State(initialValue: ChatDetailViewModel(
            chat: chat,
            chatRepository: chatRepository,
            messageRepository: messageRepository,
            router: router,
            agentService: agentService
        ))
    }

    var body: some View {
        @Bindable var titleVM = viewModel.title

        VStack(spacing: 0) {
            MessageListView(
                viewModel: viewModel,
                fileStorageService: fileStorageService
            )

            InputBarView(
                text: Binding(
                    get: { viewModel.draft.text },
                    set: { viewModel.draft.text = $0 }
                ),
                onSend: {
                    Task { await viewModel.sendMessage(text: viewModel.draft.text) }
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatTitleButton(titleVM: viewModel.title)
            }
        }

        .sheet(isPresented: $titleVM.isTitleEditing) {
            TitleEditSheet(
                title: titleVM.chat.title,
                onCommit: { newTitle in
                    Task { await viewModel.commitTitleEdit(newTitle: newTitle) }
                }
            )
            .presentationDetents([.height(160)])
        }

        .navigationDestination(item: Binding(
            get: { viewModel.imageViewer.selectedImageURL.map { ImageViewerItem(url: $0) } },
            set: { if $0 == nil { viewModel.imageViewer.dismiss() } }
        )) { item in
            ImageViewerView(item: item)
                .navigationBarHidden(true)
        }

        .onDisappear {
            viewModel.cleanUpIfEmpty()
            viewModel.saveDraftImmediately()
        }

        .task {
            await viewModel.loadMessages()
        }

        .errorAlert(errorMessage: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.dismissError() }
        ))
    }
}

private struct ChatTitleButton: View {
    var titleVM: TitleViewModel

    var body: some View {
        Button {
            titleVM.startEdit()
        } label: {
            Text(titleVM.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("chatTitleButton")
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
