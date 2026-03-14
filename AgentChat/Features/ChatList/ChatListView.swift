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
                            .accessibilityIdentifier("chatRow_\(chat.id)")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                router.push(.chatDetail(chatId: chat.id))
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
            await viewModel.loadChats()
        }
        .onChange(of: router.path.count) {
            Task { await viewModel.loadChats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .seedDataLoaded)) { _ in
            Task { await viewModel.loadChats() }
        }
    }
}
