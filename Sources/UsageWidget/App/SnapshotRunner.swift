#if DEBUG
import SwiftUI
import AppKit

/// DEBUG-only: render the real popover views (with seeded data/states) to a PNG, so the design can
/// be reviewed without clicking the menu-bar item. Invoked via `UsageWidget --snapshot[-states] <path>`.
@MainActor
enum SnapshotRunner {
    static func renderSync(outputPath: String) {
        let (store, settings) = makeStore()
        let now = Date()
        store.seed(ProviderUsage(
            providerID: .claude,
            plan: PlanInfo.from(rawPlanType: "max"),
            windows: [
                LimitWindow(kind: .fiveHour, utilization: 0.47, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
                LimitWindow(kind: .weekly, utilization: 0.63, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
                LimitWindow(kind: .weeklyOpus, utilization: 0.71, resetsAt: now.addingTimeInterval(3 * 86400)),
                LimitWindow(kind: .weeklySonnet, utilization: 0.40, resetsAt: now.addingTimeInterval(3 * 86400))
            ],
            tokens: TokenStats(inputTokens: 1_284_000, outputTokens: 96_500, cacheReadTokens: 4_120_000, estimatedCostUSD: 12.47),
            capturedAt: now.addingTimeInterval(-90)
        ))
        store.seed(ProviderUsage(
            providerID: .codex,
            plan: PlanInfo.from(rawPlanType: "pro"),
            windows: [
                LimitWindow(kind: .fiveHour, utilization: 0.88, resetsAt: now.addingTimeInterval(48 * 60)),
                LimitWindow(kind: .weekly, utilization: 0.93, resetsAt: now.addingTimeInterval(5 * 86400))
            ],
            capturedAt: now.addingTimeInterval(-30)
        ))
        write(popover(store: store, settings: settings), to: outputPath)
    }

    static func renderStatesSync(outputPath: String) {
        let (store, settings) = makeStore()
        let now = Date()
        // Claude: signed out -> shows the sign-in CTA.
        store.seedState(.init(usage: nil, phase: .idle, lastUpdated: nil, lastError: nil, authState: .signedOut), for: .claude)
        // Codex: cached data but last refresh hit a 429 -> bars stay + rate-limited chip.
        let codexUsage = ProviderUsage(
            providerID: .codex,
            plan: PlanInfo.from(rawPlanType: "plus"),
            windows: [
                LimitWindow(kind: .fiveHour, utilization: 0.62, resetsAt: now.addingTimeInterval(70 * 60)),
                LimitWindow(kind: .weekly, utilization: 0.34, resetsAt: now.addingTimeInterval(4 * 86400))
            ],
            capturedAt: now.addingTimeInterval(-600)
        )
        store.seedState(.init(usage: codexUsage, phase: .failed, lastUpdated: now.addingTimeInterval(-600),
                              lastError: .rateLimited(retryAfter: nil), authState: .signedIn), for: .codex)
        write(popover(store: store, settings: settings), to: outputPath)
    }

    // MARK: - Shared

    private static func makeStore() -> (UsageStore, SettingsModel) {
        let settings = SettingsModel()
        let providers: [any UsageProvider] = [
            MockProvider(id: .claude, displayName: "Claude", iconSystemName: "sparkle", accentHex: "#D97757"),
            MockProvider(id: .codex, displayName: "Codex", iconSystemName: "chevron.left.forwardslash.chevron.right", accentHex: "#10A37F")
        ]
        let store = UsageStore(providers: providers, cache: SnapshotCache(filename: "snapshot-preview.json"), settings: settings)
        return (store, settings)
    }

    private static func popover(store: UsageStore, settings: SettingsModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("LLM Usage").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("updated 1m ago").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.Space.popover).padding(.vertical, 10)

            Divider().overlay(Theme.separator)

            VStack(spacing: Theme.Space.cardGap) {
                ForEach(store.enabledProviders, id: \.id) { provider in
                    ProviderCard(provider: provider)
                }
            }
            .padding(Theme.Space.popover)

            Divider().overlay(Theme.separator)

            HStack {
                Label("Settings", systemImage: "gearshape")
                Spacer()
                Label("Quit", systemImage: "power")
            }
            .labelStyle(.titleAndIcon)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.Space.popover).padding(.vertical, 9)
        }
        .frame(width: Theme.popoverWidth)
        .background(Color(hex: "#020617"))
        .environment(store)
        .environment(settings)
        .colorScheme(.dark)
    }

    private static func write<V: View>(_ view: V, to outputPath: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else {
            FileHandle.standardError.write(Data("snapshot: render failed\n".utf8)); exit(1)
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: encode failed\n".utf8)); exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("snapshot: wrote \(outputPath) (\(cgImage.width)x\(cgImage.height))")
        } catch {
            FileHandle.standardError.write(Data("snapshot: write failed: \(error)\n".utf8)); exit(1)
        }
    }
}
#endif
