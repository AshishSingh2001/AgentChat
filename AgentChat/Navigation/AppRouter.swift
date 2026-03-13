import SwiftUI

@MainActor
protocol AppRouterProtocol: AnyObject {
    var path: NavigationPath { get set }
    func push(_ route: AppRoute)
    func pop()
    func popToRoot()
}

@Observable
@MainActor
final class AppRouter: AppRouterProtocol {
    var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
