import Foundation
import AppKit

/// GitHub Copilot provider: device-flow OAuth sign-in, token refresh, and monthly-quota fetch.
actor CopilotProvider: UsageProvider {
    nonisolated let id = ProviderID.copilot
    nonisolated let displayName = "Copilot"
    nonisolated let iconSystemName = "cpu"
    nonisolated let accentHex = "#A78BFA"
    nonisolated let defaultPollInterval: TimeInterval = 600  // monthly quota moves slowly
    nonisolated let minimumPollInterval: TimeInterval = 120

    private let tokens: TokenStore
    private let oauth = CopilotOAuthClient()
    private let fetcher = CopilotUsageFetcher()

    init(tokens: TokenStore) {
        self.tokens = tokens
    }

    func authState() async -> ProviderAuthState {
        await tokens.token(for: id) != nil ? .signedIn : .signedOut
    }

    func startSignIn() async throws -> SignInContinuation {
        let device = try await oauth.requestDeviceCode()
        let url = URL(string: device.verificationURI) ?? URL(string: "https://github.com/login/device")!
        await openInBrowser(url)

        let oauth = self.oauth
        let tokens = self.tokens
        let id = self.id
        return .deviceCode(
            userCode: device.userCode,
            verificationURL: url,
            instructions: "Enter this code at github.com/login/device to connect Copilot."
        ) {
            let token = try await oauth.pollForToken(deviceCode: device.deviceCode, interval: device.interval, expiresIn: device.expiresIn)
            await tokens.save(token, for: id)
        }
    }

    func signOut() async {
        await tokens.clear(id)
    }

    func fetchUsage() async throws -> ProviderUsage {
        guard var token = await tokens.token(for: id) else { throw ProviderError.notSignedIn }
        if token.needsRefresh(), token.refreshToken != nil {
            token = (try? await refreshAndStore(token)) ?? token
        }
        do {
            return try await fetcher.fetch(accessToken: token.accessToken)
        } catch ProviderError.unauthorized {
            if token.refreshToken != nil {
                let refreshed = try await refreshAndStore(token)
                return try await fetcher.fetch(accessToken: refreshed.accessToken)
            }
            await tokens.clear(id)  // non-expiring token was revoked → require re-auth
            throw ProviderError.unauthorized
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
