import SwiftUI
import AppKit

/// The popover shown when the menu-bar item is clicked: a header (title · last-updated · refresh),
/// a scrollable stack of provider cards, and a footer (Settings · Quit). Backed by native blur.
struct PopoverRootView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator)
            // Plain VStack (not ScrollView): a greedy ScrollView collapses to zero height inside a
            // content-sized MenuBarExtra(.window) popover, hiding the cards. With a handful of
            // providers the popover simply grows to fit. (Re-add a measured-height scroll if the
            // provider list ever gets long.)
            VStack(spacing: Theme.Space.cardGap) {
                if store.enabledProviders.isEmpty {
                    EmptyStateView()
                } else {
                    ForEach(store.enabledProviders, id: \.id) { provider in
                        ProviderCard(provider: provider)
                    }
                }
            }
            .padding(Theme.Space.popover)
            Divider().overlay(Theme.separator)
            footer
        }
        .frame(width: Theme.popoverWidth)
        .background(.ultraThinMaterial)
        .task { await store.refreshOnOpen() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("LLM Usage")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(RelativeTime.updatedAgo(store.lastGlobalRefresh))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
            Button {
                Task { await store.refreshAllNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .help("Refresh now")
        }
        .padding(.horizontal, Theme.Space.popover)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(Theme.textSecondary)
        .font(.system(size: 11))
        .padding(.horizontal, Theme.Space.popover)
        .padding(.vertical, 9)
    }
}
