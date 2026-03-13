import SwiftUI
@testable import AgentChat

@MainActor
final class MockAppRouter: AppRouterProtocol {
    var path = NavigationPath()
    var pushedRoutes: [AppRoute] = []
    var popCallCount = 0
    var popToRootCallCount = 0

    func push(_ route: AppRoute) {
        path.append(route)
        pushedRoutes.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
        popCallCount += 1
    }

    func popToRoot() {
        path = NavigationPath()
        popToRootCallCount += 1
    }
}
