import Foundation

/// Composition root — builds and wires the settings, cache, token store, providers, and store.
/// A single shared instance is created once at launch and injected into the scenes.
@MainActor
final class AppEnvironment {
    let settings: SettingsModel
    let store: UsageStore

    private init(settings: SettingsModel, store: UsageStore) {
        self.settings = settings
        self.store = store
    }

    static let shared: AppEnvironment = .live()

    static func live() -> AppEnvironment {
        let settings = SettingsModel()
        let cache = SnapshotCache()
        let tokens = TokenStore()
        let providers: [any UsageProvider] = [
            ClaudeProvider(tokens: tokens),
            CodexProvider(tokens: tokens)
        ]
        let store = UsageStore(providers: providers, cache: cache, settings: settings)
        return AppEnvironment(settings: settings, store: store)
    }
}
