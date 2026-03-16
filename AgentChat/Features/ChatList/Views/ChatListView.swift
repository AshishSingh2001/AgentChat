import SwiftUI

struct ChatListView: View {
    @State private var viewModel: ChatListViewModel

    init(
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol
    ) {
        _viewModel = State(initialValue: ChatListViewModel(
            chatRepository: chatRepository,
            messageRepository: messageRepository,
            router: router
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.chats.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Tap the compose button to start a chat")
                )
            } else {
                List {
                    ForEach(viewModel.chats) { chat in
                        ChatRowView(chat: chat)
                            .accessibilityIdentifier("chatRow_\(chat.id)")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.navigateToChat(chat)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteChat(chat) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.createNewChat() }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityIdentifier("newChatButton")
            }
        }
        .task {
            viewModel.startStream()
        }
        .errorAlert(errorMessage: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.dismissError() }
        ))
    }
}
