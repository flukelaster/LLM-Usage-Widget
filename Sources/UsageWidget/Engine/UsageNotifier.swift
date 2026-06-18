import Foundation
import UserNotifications

/// Posts a system notification when a provider's window crosses the high-usage threshold, once per
/// window per reset cycle (no spamming). De-dup keyed on the window's `resetsAt`, so it fires again
/// after the window rolls over.
@MainActor
final class UsageNotifier {
    static let threshold = 0.90

    private struct Key: Hashable { let provider: ProviderID; let kind: LimitWindow.Kind }
    private var notifiedFor: [Key: Date] = [:]

    /// Ask for permission the first time only (no-op if already decided).
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Pure decision step (also updates dedup state): which windows should fire a notification now.
    /// Exposed for self-checks.
    func windowsToNotify(providerID: ProviderID, usage: ProviderUsage) -> [LimitWindow] {
        var firing: [LimitWindow] = []
        for window in usage.windows where window.kind.isHero {
            let key = Key(provider: providerID, kind: window.kind)
            if window.clampedUtilization >= Self.threshold {
                let marker = window.resetsAt ?? .distantFuture
                if notifiedFor[key] != marker {
                    notifiedFor[key] = marker
                    firing.append(window)
                }
            } else {
                notifiedFor[key] = nil  // back under threshold → allow a future alert
            }
        }
        return firing
    }

    /// Evaluate a fresh snapshot and post notifications for any newly-crossed windows.
    func evaluate(providerID: ProviderID, providerName: String, usage: ProviderUsage) {
        for window in windowsToNotify(providerID: providerID, usage: usage) {
            post(providerName: providerName, window: window)
        }
    }

    func clear() { notifiedFor.removeAll() }

    private func post(providerName: String, window: LimitWindow) {
        let content = UNMutableNotificationContent()
        content.title = "\(providerName) usage at \(window.percent)%"
        content.body = "Your \(window.kind.title) limit is almost used up — \(RelativeTime.resetLabel(window.resetsAt))."
        content.sound = .default
        // Stable id per provider+window so a newer alert replaces the older one (no stacking).
        let id = "limit.\(providerName).\(window.kind.rawValue)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
