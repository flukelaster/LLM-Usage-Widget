import SwiftUI

/// Settings window: General (display, cadence, launch-at-login), Providers (enable + sign out),
/// and About. Opened from the popover footer via `SettingsLink`.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProvidersSettingsTab()
                .tabItem { Label("Providers", systemImage: "person.2") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 360)
    }
}

private struct GeneralSettingsTab: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(UsageStore.self) private var store
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            Picker("Menu bar focus", selection: $settings.menuBarProvider) {
                Text("Closest to full").tag(ProviderID?.none)
                ForEach(store.providers, id: \.id) { provider in
                    Text(provider.displayName).tag(ProviderID?.some(provider.id))
                }
            }
            .onChange(of: settings.menuBarProvider) { settings.save() }

            Picker("Menu bar shows", selection: $settings.menuBarDisplay) {
                ForEach(SettingsModel.MenuBarDisplay.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: settings.menuBarDisplay) { settings.save() }

            Picker("Refresh every", selection: $settings.pollIntervalSeconds) {
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
                Text("5 minutes").tag(300)
                Text("15 minutes").tag(900)
            }
            .onChange(of: settings.pollIntervalSeconds) { settings.save() }

            Text("Claude is always polled at most once every 5 minutes to avoid its strict rate limits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Notify when usage exceeds 90%", isOn: $settings.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { _, isOn in
                    settings.save()
                    if isOn { Task { await store.requestNotificationAuthorization() } }
                }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        try LaunchAtLogin.set(newValue)
                        launchError = nil
                    } catch {
                        launchError = error.localizedDescription
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            if let launchError {
                Text(launchError).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

private struct ProvidersSettingsTab: View {
    @Environment(UsageStore.self) private var store
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Form {
            ForEach(store.providers, id: \.id) { provider in
                providerRow(provider)
            }
            Text("Sign in to each provider from its card in the menu bar popover.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private func providerRow(_ provider: any UsageProvider) -> some View {
        let state = store.state(for: provider.id)
        let signedIn = state.authState == .signedIn
        return HStack(spacing: 10) {
            ProviderIcon(providerID: provider.id, accent: Color(hex: provider.accentHex), size: 17)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.displayName)
                Text(signedIn ? "Signed in" : "Signed out")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if signedIn {
                Button("Sign out") { Task { await store.signOut(provider.id) } }
                    .controlSize(.small)
            }
            Toggle("", isOn: Binding(
                get: { settings.isEnabled(provider.id) },
                set: { newValue in
                    settings.setEnabled(newValue, for: provider.id)
                    store.reschedule()
                }
            ))
            .labelsHidden()
        }
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
            Text("LLM Usage Widget").font(.headline)
            Text("Version 0.3.0").font(.subheadline).foregroundStyle(.secondary)
            Text("Real-time Claude, Codex & Copilot usage limits in your menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
