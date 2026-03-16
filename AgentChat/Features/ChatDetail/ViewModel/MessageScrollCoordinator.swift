import Foundation

@Observable
@MainActor
final class MessageScrollCoordinator {
    private enum Constants {
        static let scrollThreshold: CGFloat = 150
        static let toastDismissDelay: TimeInterval = 3
    }

    var shouldScrollToBottom = false
    var showNewMessageToast = false
    var isNearBottom = true
    var scrollDelay: Duration = .zero

    private var toastTask: Task<Void, Never>?

    func updateScrollOffset(_ offsetFromBottom: CGFloat) {
        let newValue = offsetFromBottom < Constants.scrollThreshold
        if newValue != isNearBottom { isNearBottom = newValue }
    }

    func handleNewMessage(from sender: Sender, type: MessageType = .text) {
        if sender == .user || isNearBottom {
            scrollDelay = type == .file ? .milliseconds(500) : .zero
            shouldScrollToBottom = true
        } else {
            showNewMessageToast = true
            scheduleToastDismiss()
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toastTask = nil
        showNewMessageToast = false
    }

    private func scheduleToastDismiss() {
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(Constants.toastDismissDelay))
            guard !Task.isCancelled else { return }
            showNewMessageToast = false
        }
    }
}
