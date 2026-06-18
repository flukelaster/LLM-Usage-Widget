import Foundation

/// Owns one cancellable polling loop per provider. Each loop calls back into the store to
/// perform a refresh and asks it how long to wait before the next one (so the store can apply
/// backoff after a 429). MainActor-isolated because it drives the MainActor store directly.
@MainActor
final class RefreshScheduler {
    private var tasks: [ProviderID: Task<Void, Never>] = [:]

    /// (Re)start a loop for `id`. `tick` performs one refresh and returns the seconds to wait next.
    func start(_ id: ProviderID, tick: @escaping @MainActor (ProviderID) async -> TimeInterval) {
        stop(id)
        tasks[id] = Task { @MainActor in
            while !Task.isCancelled {
                let delay = await tick(id)
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    var activeIDs: Set<ProviderID> { Set(tasks.keys) }

    func isRunning(_ id: ProviderID) -> Bool { tasks[id] != nil }

    func stop(_ id: ProviderID) {
        tasks[id]?.cancel()
        tasks[id] = nil
    }

    func stopAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }
}
