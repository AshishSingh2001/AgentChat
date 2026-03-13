import Testing
import SwiftUI
@testable import AgentChat

@MainActor
struct AppRouterTests {

    @Test func pushIncreasesPathCount() {
        let router = AppRouter()
        router.push(.chatDetail(chatId: "x"))
        #expect(router.path.count == 1)
    }

    @Test func popDecreasesPathCount() {
        let router = AppRouter()
        router.push(.chatDetail(chatId: "x"))
        router.pop()
        #expect(router.path.count == 0)
    }

    @Test func popToRootClearsAllRoutes() {
        let router = AppRouter()
        router.push(.chatDetail(chatId: "a"))
        router.push(.chatDetail(chatId: "b"))
        router.push(.chatDetail(chatId: "c"))
        router.popToRoot()
        #expect(router.path.count == 0)
    }

    @Test func pushSameRouteTwiceGivesPathCountTwo() {
        let router = AppRouter()
        router.push(.chatDetail(chatId: "x"))
        router.push(.chatDetail(chatId: "x"))
        #expect(router.path.count == 2)
    }
}
