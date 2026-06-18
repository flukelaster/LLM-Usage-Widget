import SwiftUI

struct UsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let env = AppEnvironment.shared

        MenuBarExtra {
            PopoverRootView()
                .environment(env.store)
                .environment(env.settings)
        } label: {
            MenuBarLabel()
                .environment(env.store)
                .environment(env.settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(env.store)
                .environment(env.settings)
        }
    }
}
