import SwiftUI

struct ChatListView: View {
    @State private var viewModel: ChatListViewModel
    @Environment(AppRouter.self) private var router

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
            if viewModel.chats.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Tap the compose button to start a chat")
                )
            } else {
                List {
                    ForEach(viewModel.chats) { chat in
                        ChatRowView(chat: chat)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                router.push(.chatDetail(chatId: chat.id))
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.requestDeleteChat(chat)
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
            }
        }
        .task(id: router.path.count) {
            await viewModel.loadChats()
        }
        .confirmationDialog(
            "Delete \"\(viewModel.chatPendingDeletion?.title ?? "")\"?",
            isPresented: Binding(
                get: { viewModel.chatPendingDeletion != nil },
                set: { if !$0 { viewModel.cancelDeleteChat() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.confirmDeleteChat() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteChat()
            }
        }
    }
}
