import SwiftUI

@main
struct AgentChatApp: App {
    private let persistence = PersistenceController()
    private let fileStorageService = FileStorageService()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppView(
                chatRepository: persistence.chatRepository,
                messageRepository: persistence.messageRepository,
                fileStorageService: fileStorageService,
                agentService: {
                    let args = ProcessInfo.processInfo.arguments
                    let delayRange: ClosedRange<Double> = args.contains("--uitesting-slow-agent") ? 6.0...8.0 : 2.0...3.0
                    let decider = args.contains("--uitesting-reply-every-4")
                        ? SimulateAgentReplyUseCase(config: .init(replyIntervalRange: 4...4, imageChancePercent: 0))
                        : SimulateAgentReplyUseCase()
                    return AgentService(
                        messageRepository: persistence.messageRepository,
                        chatRepository: persistence.chatRepository,
                        delayRange: delayRange,
                        decider: decider
                    )
                }()
            )
            .environment(router)
            .onAppear {
                let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting-reset")
                persistence.seed(resetForTesting: isUITesting)
            }
        }
    }
}
