import Foundation
import AppKit

/// Codex provider: loopback OAuth sign-in (127.0.0.1:1455), token refresh, and usage fetch.
actor CodexProvider: UsageProvider {
    nonisolated let id = ProviderID.codex
    nonisolated let displayName = "Codex"
    nonisolated let iconSystemName = "chevron.left.forwardslash.chevron.right"
    nonisolated let accentHex = "#10A37F"
    nonisolated let defaultPollInterval: TimeInterval = 120
    nonisolated let minimumPollInterval: TimeInterval = 60

    private let tokens: TokenStore
    private let oauth = CodexOAuthClient()
    private let fetcher = CodexUsageFetcher()

    init(tokens: TokenStore) {
        self.tokens = tokens
    }

    func authState() async -> ProviderAuthState {
        await tokens.token(for: id) != nil ? .signedIn : .signedOut
    }

    func startSignIn() async throws -> SignInContinuation {
        let pkce = PKCE.generate()
        let server = LoopbackOAuthServer(port: CodexOAuthClient.loopbackPort)
        let url = oauth.makeAuthorizeURL(pkce: pkce)
        await openInBrowser(url)

        let result: LoopbackResult
        do {
            result = try await server.waitForCallback()
        } catch {
            server.stop()
            throw error
        }
        guard result.state == pkce.state else { throw OAuthError.stateMismatch }

        let token = try await oauth.exchange(code: result.code, pkce: pkce)
        await tokens.save(token, for: id)
        return .completed
    }

    func signOut() async {
        await tokens.clear(id)
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard var token = await tokens.token(for: id) else { throw ProviderError.notSignedIn }
        if token.needsRefresh() {
            token = try await refreshAndStore(token)
        }
        do {
            return try await fetcher.fetch(accessToken: token.accessToken, accountId: token.accountId, planFallback: token.planType)
        } catch ProviderError.unauthorized {
            let refreshed = try await refreshAndStore(token)
            return try await fetcher.fetch(accessToken: refreshed.accessToken, accountId: refreshed.accountId, planFallback: refreshed.planType)
        }
    }

    private func refreshAndStore(_ token: OAuthToken) async throws -> OAuthToken {
        do {
            let refreshed = try await oauth.refresh(token)
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
