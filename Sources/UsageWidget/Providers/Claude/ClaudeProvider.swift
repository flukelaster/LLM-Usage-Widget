import Foundation
import AppKit

/// Claude provider: paste-code OAuth sign-in, token refresh (proactive + reactive), and usage fetch.
actor ClaudeProvider: UsageProvider {
    nonisolated let id = ProviderID.claude
    nonisolated let displayName = "Claude"
    nonisolated let iconSystemName = "sparkle"
    nonisolated let accentHex = "#D97757"
    nonisolated let defaultPollInterval: TimeInterval = 300
    nonisolated let minimumPollInterval: TimeInterval = 300

    private let tokens: TokenStore
    private let oauth = ClaudeOAuthClient()
    private let fetcher = ClaudeUsageFetcher()
    private let profile = ClaudeProfileFetcher()

    init(tokens: TokenStore) {
        self.tokens = tokens
    }

    func authState() async -> ProviderAuthState {
        await tokens.token(for: id) != nil ? .signedIn : .signedOut
    }

    func startSignIn() async throws -> SignInContinuation {
        let pkce = PKCE.generate()
        let url = oauth.makeAuthorizeURL(pkce: pkce)
        await openInBrowser(url)

        let oauth = self.oauth
        let tokens = self.tokens
        let id = self.id
        let instructions = "Approve access in your browser, then paste the code it shows (looks like \"abc123#xyz\")."
        return .needsCode(instructions: instructions) { pastedCode in
            let token = try await oauth.exchange(pastedCode: pastedCode, pkce: pkce)
            await tokens.save(token, for: id)
        }
    }

    func signOut() async {
        await tokens.clear(id)
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard var token = await tokens.token(for: id) else { throw ProviderError.notSignedIn }
        if token.needsRefresh() {
            token = try await refreshAndStore(token)
        }
        token = await ensurePlan(token)
        do {
            return try await fetcher.fetch(accessToken: token.accessToken, plan: token.planType)
        } catch ProviderError.unauthorized {
            var refreshed = try await refreshAndStore(token)
            refreshed = await ensurePlan(refreshed)
            return try await fetcher.fetch(accessToken: refreshed.accessToken, plan: refreshed.planType)
        }
    }

    /// The usage endpoint carries no plan, so fetch the profile once and cache it on the token.
    /// Best-effort: a failure just leaves the badge off — usage still loads.
    private func ensurePlan(_ token: OAuthToken) async -> OAuthToken {
        guard token.planType == nil else { return token }
        guard let raw = (try? await profile.fetchRawPlan(accessToken: token.accessToken)) ?? nil else {
            return token
        }
        var updated = token
        updated.planType = raw
        await tokens.save(updated, for: id)
        return updated
    }

    private func refreshAndStore(_ token: OAuthToken) async throws -> OAuthToken {
        do {
            var refreshed = try await oauth.refresh(token)
            refreshed.planType = refreshed.planType ?? token.planType   // keep the cached plan
            await tokens.save(refreshed, for: id)
            return refreshed
        } catch {
            await tokens.clear(id)
            throw ProviderError.unauthorized
        }
    }

    @MainActor
    private func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
