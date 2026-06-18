import Foundation

/// A configurable in-memory provider for development, the first runnable build, and previews.
/// Lets us build the engine and views against realistic data before real OAuth is wired in.
actor MockProvider: UsageProvider {
    nonisolated let id: ProviderID
    nonisolated let displayName: String
    nonisolated let iconSystemName: String
    nonisolated let accentHex: String
    nonisolated let defaultPollInterval: TimeInterval
    nonisolated let minimumPollInterval: TimeInterval

    enum Scenario: Sendable {
        case healthy      // low usage
        case nearLimit    // high usage, draws amber/red
        case rateLimited  // throws .rateLimited to exercise that state
        case signedOut
    }

    private var signedIn: Bool
    private let scenario: Scenario
    private let planType: String

    init(
        id: ProviderID,
        displayName: String,
        iconSystemName: String,
        accentHex: String,
        scenario: Scenario = .healthy,
        planType: String = "pro",
        defaultPollInterval: TimeInterval = 60,
        minimumPollInterval: TimeInterval = 30
    ) {
        self.id = id
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.accentHex = accentHex
        self.scenario = scenario
        self.planType = planType
        self.defaultPollInterval = defaultPollInterval
        self.minimumPollInterval = minimumPollInterval
        self.signedIn = scenario != .signedOut
    }

    func authState() async -> ProviderAuthState { signedIn ? .signedIn : .signedOut }

    func startSignIn() async throws -> SignInContinuation {
        signedIn = true
        return .completed
    }

    func signOut() async { signedIn = false }

    func fetchUsage() async throws -> ProviderUsage {
        guard signedIn else { throw ProviderError.notSignedIn }
        if case .rateLimited = scenario { throw ProviderError.rateLimited(retryAfter: nil) }

        // Small artificial latency so loading states are visible during development.
        try? await Task.sleep(for: .milliseconds(250))

        let (five, week): (Double, Double) = scenario == .nearLimit ? (0.88, 0.93) : (0.47, 0.63)
        let now = Date()
        return ProviderUsage(
            providerID: id,
            plan: PlanInfo.from(rawPlanType: planType),
            windows: [
                LimitWindow(kind: .fiveHour, utilization: five, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
                LimitWindow(kind: .weekly, utilization: week, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600))
            ],
            tokens: TokenStats(inputTokens: 1_284_000, outputTokens: 96_500, cacheReadTokens: 4_120_000, estimatedCostUSD: 12.47, since: now.addingTimeInterval(-5 * 3600)),
            capturedAt: now
        )
    }
}
