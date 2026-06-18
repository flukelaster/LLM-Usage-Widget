import Foundation

/// Stable identifier for a usage provider. Open by design — adding a provider is just
/// a new static constant plus a concrete `UsageProvider` implementation.
struct ProviderID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    static let claude = ProviderID(rawValue: "claude")
    static let codex = ProviderID(rawValue: "codex")
}
