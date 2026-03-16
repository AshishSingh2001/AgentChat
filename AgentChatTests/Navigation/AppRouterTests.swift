import Testing
import SwiftUI
@testable import AgentChat

@MainActor
struct AppRouterTests {

    private static let chat = Chat(id: "x", title: "Test", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)

    @Test func pushIncreasesPathCount() {
        let router = AppRouter()
        router.push(.chatDetail(chat: Self.chat))
        #expect(router.path.count == 1)
    }

    @Test func popDecreasesPathCount() {
        let router = AppRouter()
        router.push(.chatDetail(chat: Self.chat))
        router.pop()
        #expect(router.path.count == 0)
    }

    @Test func popToRootClearsAllRoutes() {
        let router = AppRouter()
        let a = Chat(id: "a", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let b = Chat(id: "b", title: "B", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let c = Chat(id: "c", title: "C", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        router.push(.chatDetail(chat: a))
        router.push(.chatDetail(chat: b))
        router.push(.chatDetail(chat: c))
        router.popToRoot()
        #expect(router.path.count == 0)
    }

    @Test func pushSameRouteTwiceGivesPathCountTwo() {
        let router = AppRouter()
        router.push(.chatDetail(chat: Self.chat))
        router.push(.chatDetail(chat: Self.chat))
        #expect(router.path.count == 2)
    }
}
