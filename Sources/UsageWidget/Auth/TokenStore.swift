import Foundation

/// Serializes Keychain access for OAuth tokens. An actor so concurrent provider refreshes can't
/// race on read-modify-write of the same credentials.
actor TokenStore {
    private let keychain: KeychainStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(service: String = "com.flukelaster.usagewidget") {
        self.keychain = KeychainStore(service: service)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    private func account(_ id: ProviderID) -> String { "\(id.rawValue).oauth" }

    func token(for id: ProviderID) -> OAuthToken? {
        guard let data = try? keychain.get(account: account(id)) else { return nil }
        return try? decoder.decode(OAuthToken.self, from: data)
    }

    func save(_ token: OAuthToken, for id: ProviderID) {
        guard let data = try? encoder.encode(token) else {
            Log.auth.error("TokenStore: failed to encode token for \(id.rawValue, privacy: .public)")
            return
        }
        do {
            try keychain.set(data, account: account(id))
        } catch {
            Log.auth.error("TokenStore: failed to save token: \(error.localizedDescription)")
        }
    }

    func clear(_ id: ProviderID) {
        try? keychain.delete(account: account(id))
    }
}
