import Foundation

@Observable
@MainActor
final class DraftViewModel {
    private enum Constants {
        static let debounceDelay: Duration = .milliseconds(300)
    }

    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            debouncedSave()
        }
    }

    private var currentChat: Chat?
    private var repository: (any ChatRepositoryProtocol)?
    private var saveTask: Task<Void, Never>?

    func configure(chat: Chat, repository: any ChatRepositoryProtocol) {
        currentChat = chat
        self.repository = repository
    }

    func saveImmediately() {
        saveTask?.cancel()
        saveTask = nil
        persistDraft()
    }

    func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Constants.debounceDelay)
            guard !Task.isCancelled else { return }
            persistDraft()
        }
    }

    private func persistDraft() {
        guard let chat = currentChat, let repo = repository else { return }
        let draft = text
        Task {
            try? await repo.updateDraft(id: chat.id, draftText: draft)
        }
    }
}
