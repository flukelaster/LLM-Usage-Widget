import Foundation

/// Exponential backoff with jitter, for endpoints that rate-limit aggressively — notably
/// Claude's usage API, which often returns 429 with no `Retry-After`. When the server does
/// provide a delay, we honor it; otherwise we grow the delay geometrically up to a cap.
struct BackoffPolicy: Sendable {
    let base: TimeInterval
    let maxDelay: TimeInterval
    private(set) var attempt: Int = 0

    init(base: TimeInterval = 60, maxDelay: TimeInterval = 30 * 60) {
        self.base = base
        self.maxDelay = maxDelay
    }

    var isBackingOff: Bool { attempt > 0 }

    /// Advance the attempt counter and return the delay before the next try.
    mutating func nextDelay(retryAfter: TimeInterval?) -> TimeInterval {
        attempt += 1
        if let retryAfter, retryAfter > 0 {
            return min(retryAfter, maxDelay)
        }
        let exp = base * pow(2, Double(attempt - 1))
        let capped = min(exp, maxDelay)
        let jitter = Double.random(in: 0...(capped * 0.25))
        return min(capped + jitter, maxDelay)
    }

    mutating func reset() { attempt = 0 }
}
