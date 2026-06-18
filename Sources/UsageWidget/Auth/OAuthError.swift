import Foundation

/// Errors raised by the OAuth clients and loopback server.
enum OAuthError: Error, Sendable, LocalizedError {
    case timeout
    case missingCallbackParameters
    case stateMismatch
    case invalidResponse
    case portUnavailable(UInt16)
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Sign-in timed out. Please try again."
        case .missingCallbackParameters: return "The browser redirect was missing the authorization code."
        case .stateMismatch: return "Security check failed (state mismatch). Please try again."
        case .invalidResponse: return "The server returned an unexpected response."
        case .portUnavailable(let port): return "Port \(port) is in use. Close the app using it and retry."
        case .http(let status, _): return "Authentication failed (HTTP \(status))."
        }
    }
}
