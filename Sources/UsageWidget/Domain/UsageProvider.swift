import Foundation

/// Errors a provider can surface. The engine maps these into per-provider UI states.
enum ProviderError: Error, Sendable, Equatable {
    /// No stored credentials — the card should prompt sign-in.
    case notSignedIn
    /// Token rejected (401). The provider tries one refresh+retry before throwing this.
    case unauthorized
    /// 429. `retryAfter` is honored when the server provides it; otherwise the engine backs off.
    case rateLimited(retryAfter: TimeInterval?)
    /// Network/transport failure (offline, DNS, TLS, timeouts).
    case transport(String)
    /// Response could not be decoded into the expected shape.
    case decoding(String)
}

/// How a sign-in flow proceeds after it begins. Different providers need different UX:
/// Codex completes autonomously via a loopback redirect; Claude needs the user to paste a code.
enum SignInContinuation: Sendable {
    /// Sign-in finished inside `startSignIn()` (e.g. Codex loopback captured the code).
    case completed
    /// The browser is showing a code the user must paste back. Call `submit(code)` to finish.
    case needsCode(instructions: String, submit: @Sendable (String) async throws -> Void)
    /// Device flow: show `userCode` for the user to enter at `verificationURL`, then await `poll`
    /// (which resolves when the user authorizes). Used by GitHub Copilot.
    case deviceCode(userCode: String, verificationURL: URL, instructions: String, poll: @Sendable () async throws -> Void)
}

enum ProviderAuthState: Sendable, Equatable {
    case signedOut
    case signedIn
}

/// Everything the app needs from a provider: identity, presentation, auth, and a usage fetch.
/// Concrete providers wrap an OAuth client + token store + usage fetcher behind this.
protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    /// SF Symbol name for the card header and (optionally) the menu bar.
    var iconSystemName: String { get }
    /// Brand accent as a hex string (e.g. "#D97757"); converted to Color in the UI layer.
    var accentHex: String { get }

    /// Normal polling cadence. Claude is large here because its endpoint rate-limits hard.
    var defaultPollInterval: TimeInterval { get }
    /// Hard floor the scheduler must never poll faster than (protects rate-limited endpoints).
    var minimumPollInterval: TimeInterval { get }

    func authState() async -> ProviderAuthState
    /// Begin OAuth. Returns whether it completed or needs a pasted code (see `SignInContinuation`).
    func startSignIn() async throws -> SignInContinuation
    func signOut() async

    /// Fetch a fresh usage snapshot. Throws `ProviderError` for the engine to map to UI state.
    func fetchUsage() async throws -> ProviderUsage
}
