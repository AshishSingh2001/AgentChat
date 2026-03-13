import SwiftUI

struct AppView: View {
    @Environment(AppRouter.self) private var router
    let chatRepository: any ChatRepositoryProtocol
    let messageRepository: any MessageRepositoryProtocol
    let fileStorageService: FileStorageService

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Text("Chats — Phase 6 coming soon")
                .navigationTitle("Chats")
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .chatDetail(let chatId):
                        Text("Chat Detail: \(chatId) — Phase 7 coming soon")
                    }
                }
        }
    }
}
