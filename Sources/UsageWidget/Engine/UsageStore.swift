import Foundation
import Observation

/// The single source of truth for the UI. Holds per-provider state, drives polling via the
/// scheduler, applies backoff on rate limits, and persists last-good snapshots. MainActor so
/// SwiftUI observation is trivially correct; network happens off-main inside each provider.
@MainActor
@Observable
final class UsageStore {
    struct ProviderState: Sendable {
        var usage: ProviderUsage?
        var phase: Phase = .idle
        var lastUpdated: Date?
        var lastError: ProviderError?
        var authState: ProviderAuthState = .signedOut

        enum Phase: Sendable, Equatable { case idle, loading, loaded, failed }

        /// True when we hold data but it's old relative to the poll cadence.
        func isStale(maxAge: TimeInterval) -> Bool {
            guard let lastUpdated else { return false }
            return Date().timeIntervalSince(lastUpdated) > maxAge
        }
    }

    private(set) var states: [ProviderID: ProviderState] = [:]
    private(set) var lastGlobalRefresh: Date?

    /// Providers in display order.
    let providers: [any UsageProvider]

    @ObservationIgnored private let cache: SnapshotCache
    @ObservationIgnored private let settings: SettingsModel
    @ObservationIgnored private let scheduler = RefreshScheduler()
    @ObservationIgnored private var backoff: [ProviderID: BackoffPolicy] = [:]
    @ObservationIgnored private var nextDelayOverride: [ProviderID: TimeInterval] = [:]
    @ObservationIgnored private var didStart = false

    init(providers: [any UsageProvider], cache: SnapshotCache, settings: SettingsModel) {
        self.providers = providers
        self.cache = cache
        self.settings = settings
    }

    // MARK: - Derived state

    func state(for id: ProviderID) -> ProviderState { states[id] ?? ProviderState() }

    var enabledProviders: [any UsageProvider] {
        providers.filter { settings.isEnabled($0.id) }
    }

    /// Highest utilization across enabled providers — drives the menu-bar headline number.
    var headlineUtilization: Double {
        enabledProviders
            .compactMap { states[$0.id]?.usage?.maxUtilization }
            .max() ?? 0
    }

    var hasAnyData: Bool { states.values.contains { $0.usage != nil } }
    var anySignedIn: Bool { states.values.contains { $0.authState == .signedIn } }
    var anyEnabledSignedIn: Bool {
        enabledProviders.contains { states[$0.id]?.authState == .signedIn }
    }

    func provider(for id: ProviderID) -> (any UsageProvider)? {
        providers.first { $0.id == id }
    }

    // MARK: - Lifecycle

    /// Hydrate from cache, read auth state, and start polling loops. Idempotent.
    func start() async {
        guard !didStart else { return }
        didStart = true
        let cached = await cache.load()
        for (id, usage) in cached {
            var s = states[id] ?? ProviderState()
            s.usage = usage
            s.lastUpdated = usage.capturedAt
            states[id] = s
        }
        for provider in providers {
            let auth = await provider.authState()
            states[provider.id, default: ProviderState()].authState = auth
        }
        reschedule()
    }

    /// Start/stop loops to match the currently-enabled, signed-in providers.
    func reschedule() {
        for provider in providers {
            let enabled = settings.isEnabled(provider.id)
            let signedIn = states[provider.id]?.authState == .signedIn
            if enabled && signedIn {
                if !scheduler.isRunning(provider.id) {
                    scheduler.start(provider.id) { [weak self] id in
                        await self?.tick(id) ?? 3600
                    }
                }
            } else {
                scheduler.stop(provider.id)
            }
        }
    }

    func stop() {
        scheduler.stopAll()
    }

    // MARK: - Polling

    /// One poll cycle for a provider: refresh, then report how long to wait before the next.
    private func tick(_ id: ProviderID) async -> TimeInterval {
        await refresh(id)
        if let override = nextDelayOverride[id] {
            return override
        }
        return normalInterval(for: id)
    }

    private func normalInterval(for id: ProviderID) -> TimeInterval {
        let provider = provider(for: id)
        let floor = provider?.minimumPollInterval ?? 60
        return max(TimeInterval(settings.pollIntervalSeconds), floor)
    }

    /// Refresh a single provider now. Used by the scheduler, manual refresh, and on popover open.
    func refresh(_ id: ProviderID) async {
        guard let provider = provider(for: id) else { return }

        let auth = await provider.authState()
        states[id, default: ProviderState()].authState = auth
        guard auth == .signedIn else {
            states[id]?.phase = .idle
            return
        }

        states[id]?.phase = .loading

        do {
            let usage = try await provider.fetchUsage()
            var s = states[id] ?? ProviderState()
            s.usage = usage
            s.phase = .loaded
            s.lastUpdated = Date()
            s.lastError = nil
            s.authState = .signedIn
            states[id] = s

            backoff[id]?.reset()
            nextDelayOverride[id] = nil
            lastGlobalRefresh = Date()
            await persist()
        } catch let error as ProviderError {
            handle(error, for: id)
        } catch {
            handle(.transport(error.localizedDescription), for: id)
        }
    }

    /// Manual "refresh now" — bypasses backoff delays by fetching every enabled provider immediately.
    func refreshAllNow() async {
        let ids = enabledProviders.map(\.id)
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { [self] in
                    await self.refresh(id)
                }
            }
        }
    }

    /// Refresh on popover open, but skip providers refreshed within their minimum interval to
    /// avoid hammering Claude into a 429.
    func refreshOnOpen() async {
        for provider in enabledProviders {
            let s = state(for: provider.id)
            guard s.authState == .signedIn else { continue }
            if let last = s.lastUpdated, Date().timeIntervalSince(last) < provider.minimumPollInterval {
                continue
            }
            await refresh(provider.id)
        }
    }

    private func handle(_ error: ProviderError, for id: ProviderID) {
        var s = states[id] ?? ProviderState()
        s.phase = .failed
        s.lastError = error
        // Keep s.usage (last good) so the card never blanks out.
        switch error {
        case .unauthorized, .notSignedIn:
            s.authState = .signedOut
        default:
            break
        }
        states[id] = s

        if case .rateLimited(let retryAfter) = error {
            var policy = backoff[id] ?? BackoffPolicy()
            let delay = policy.nextDelay(retryAfter: retryAfter)
            backoff[id] = policy
            nextDelayOverride[id] = delay
            Log.engine.notice("\(id.rawValue, privacy: .public) rate-limited; backing off \(Int(delay))s")
        } else {
            nextDelayOverride[id] = nil
        }
    }

    private func persist() async {
        var snapshots: [ProviderID: ProviderUsage] = [:]
        for (id, s) in states {
            if let usage = s.usage { snapshots[id] = usage }
        }
        await cache.save(snapshots)
    }

    // MARK: - Auth

    /// Begin sign-in. For loopback providers this completes here; for paste-code providers the
    /// returned continuation carries a `submit(code:)` closure the UI calls after the user pastes.
    func startSignIn(_ id: ProviderID) async throws -> SignInContinuation {
        guard let provider = provider(for: id) else { throw ProviderError.notSignedIn }
        let continuation = try await provider.startSignIn()
        if case .completed = continuation {
            await onAuthChanged(id)
        }
        return continuation
    }

    /// Call after a paste-code `submit` succeeds, to refresh state and start polling.
    func finishSignIn(_ id: ProviderID) async {
        await onAuthChanged(id)
    }

    func signOut(_ id: ProviderID) async {
        guard let provider = provider(for: id) else { return }
        await provider.signOut()
        scheduler.stop(id)
        backoff[id] = nil
        nextDelayOverride[id] = nil
        states[id] = ProviderState(usage: nil, phase: .idle, lastUpdated: nil, lastError: nil, authState: .signedOut)
        await persist()
    }

    private func onAuthChanged(_ id: ProviderID) async {
        guard let provider = provider(for: id) else { return }
        let auth = await provider.authState()
        states[id, default: ProviderState()].authState = auth
        reschedule()
        if auth == .signedIn {
            await refresh(id)
        }
    }

    #if DEBUG
    /// Synchronously seed a provider's state for previews/snapshots (no network).
    func seed(_ usage: ProviderUsage, authState: ProviderAuthState = .signedIn) {
        states[usage.providerID] = ProviderState(
            usage: usage, phase: .loaded, lastUpdated: usage.capturedAt, lastError: nil, authState: authState
        )
        lastGlobalRefresh = usage.capturedAt
    }

    /// Seed an arbitrary state (signed-out, rate-limited, etc.) for snapshots.
    func seedState(_ state: ProviderState, for id: ProviderID) {
        states[id] = state
    }
    #endif
}
