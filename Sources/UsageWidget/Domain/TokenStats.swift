import Foundation

/// Optional secondary token/cost detail, shown in the collapsible "Details" section.
/// May be `nil` when a provider doesn't expose token counts through its live endpoint.
struct TokenStats: Hashable, Codable, Sendable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheReadTokens: Int?
    var cacheWriteTokens: Int?
    var estimatedCostUSD: Double?
    var since: Date?

    init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheReadTokens: Int? = nil,
        cacheWriteTokens: Int? = nil,
        estimatedCostUSD: Double? = nil,
        since: Date? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.since = since
    }

    /// Sum of all known token buckets, or `nil` if none are present.
    var totalTokens: Int? {
        let parts = [inputTokens, outputTokens, cacheReadTokens, cacheWriteTokens].compactMap { $0 }
        return parts.isEmpty ? nil : parts.reduce(0, +)
    }

    var hasAnyValue: Bool {
        totalTokens != nil || estimatedCostUSD != nil
    }
}
