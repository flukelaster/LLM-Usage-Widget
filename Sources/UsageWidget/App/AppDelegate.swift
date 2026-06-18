import AppKit

/// Owns app-lifecycle concerns the SwiftUI `App` can't express directly: forcing menu-bar-only
/// activation, kicking off the polling engine, and bumping to a regular app while the Settings
/// window is open (so it can take focus — accessory apps otherwise can't front a window).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let settingsWindowID = "com_apple_SwiftUI_Settings_window"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowDidBecomeKey(_:)),
                           name: NSWindow.didBecomeKeyNotification, object: nil)
        center.addObserver(self, selector: #selector(windowWillClose(_:)),
                           name: NSWindow.willCloseNotification, object: nil)

        Task { await AppEnvironment.shared.store.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.store.stop()
    }

    @objc private func windowDidBecomeKey(_ note: Notification) {
        guard isSettingsWindow(note.object as? NSWindow) else { return }
        NSApp.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ note: Notification) {
        guard isSettingsWindow(note.object as? NSWindow) else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private func isSettingsWindow(_ window: NSWindow?) -> Bool {
        window?.identifier?.rawValue == Self.settingsWindowID
    }
}
