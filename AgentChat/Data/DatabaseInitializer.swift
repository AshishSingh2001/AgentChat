import Foundation

actor DatabaseInitializer {
    private var isReady = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Default init — starts unready; call `markReady()` after seed completes.
    init() {}

    /// Convenience init for tests — starts already ready, so no call suspends.
    init(readyForTesting: Bool) {
        self.isReady = readyForTesting
    }

    func waitForInit() async {
        guard !isReady else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func markReady() {
        isReady = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
