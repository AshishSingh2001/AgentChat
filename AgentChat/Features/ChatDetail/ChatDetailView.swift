import SwiftUI

struct ChatDetailView: View {
    @State private var viewModel: ChatDetailViewModel
    let fileStorageService: FileStorageService

    init(
        chat: Chat,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        fileStorageService: FileStorageService
    ) {
        _viewModel = State(initialValue: ChatDetailViewModel(
            chat: chat,
            chatRepository: chatRepository,
            messageRepository: messageRepository,
            router: router
        ))
        self.fileStorageService = fileStorageService
    }

    var body: some View {
        @Bindable var vm = viewModel
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, fileStorageService: fileStorageService)
            InputBarView(text: $vm.draftText) {
                Task { await viewModel.sendMessage(text: viewModel.draftText) }
            }
        }
        .navigationTitle(viewModel.chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    viewModel.startTitleEdit()
                } label: {
                    Text(viewModel.chat.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isTitleEditing },
            set: { if !$0 { viewModel.isTitleEditing = false } }
        )) {
            TitleEditSheet(
                title: viewModel.chat.title,
                onCommit: { newTitle in
                    Task { await viewModel.commitTitleEdit(newTitle: newTitle) }
                }
            )
            .presentationDetents([.height(160)])
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
