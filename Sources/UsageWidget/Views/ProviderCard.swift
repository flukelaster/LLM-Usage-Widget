import SwiftUI

/// One provider's card: header (icon · name · plan · status) and the hero limit-window bars,
/// with every state handled — signed-out, paste-code sign-in, loading, loaded, rate-limited,
/// stale, and error. Never blanks out when cached data exists.
struct ProviderCard: View {
    let provider: any UsageProvider
    @Environment(UsageStore.self) private var store

    @State private var isAuthenticating = false
    @State private var pendingSubmit: (@Sendable (String) async throws -> Void)?
    @State private var pendingInstructions = ""
    @State private var codeInput = ""
    @State private var authError: String?

    private var accent: Color { Color(hex: provider.accentHex) }
    private var state: UsageStore.ProviderState { store.state(for: provider.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.barGap) {
            header
            content
        }
        .padding(Theme.Space.card)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: provider.iconSystemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18)
            Text(provider.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            if let plan = state.usage?.plan {
                PlanBadge(plan: plan, accent: accent)
            }
            Spacer()
            statusView
        }
    }

    @ViewBuilder private var statusView: some View {
        if state.phase == .loading {
            ProgressView().controlSize(.small).scaleEffect(0.8)
        } else if state.phase == .failed {
            if case .rateLimited = state.lastError {
                StatusChip(text: "Rate-limited", kind: .warn, systemImage: "clock.arrow.circlepath")
            } else {
                StatusChip(text: "Can't refresh", kind: .error, systemImage: "exclamationmark.triangle.fill")
            }
        } else if state.authState == .signedIn, state.usage != nil {
            if state.isStale(maxAge: max(provider.minimumPollInterval * 3, 900)) {
                StatusChip(text: RelativeTime.updatedAgo(state.lastUpdated), kind: .neutral)
            } else {
                StatusChip(text: "Up to date", kind: .ok)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if state.authState == .signedOut {
            signInView
        } else if let usage = state.usage {
            bars(usage)
        } else if state.phase == .loading {
            skeleton
        } else if let error = state.lastError {
            errorView(error)
        } else {
            skeleton
        }
    }

    private func bars(_ usage: ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.barGap) {
            ForEach(usage.heroWindows) { window in
                LimitWindowBar(window: window)
            }
            TokenDetailSection(usage: usage)
            if state.phase == .failed {
                inlineErrorNote
            }
        }
        .opacity(state.phase == .failed ? 0.85 : 1)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Theme.Space.barGap) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Theme.Space.tight) {
                    HStack {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.barTrack).frame(width: 48, height: 10)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3).fill(Theme.barTrack).frame(width: 38, height: 18)
                    }
                    Capsule().fill(Theme.barTrack).frame(height: Theme.barHeight)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.barTrack).frame(width: 86, height: 9)
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private func errorView(_ error: ProviderError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(friendly(error))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Button("Retry") {
                Task { await store.refresh(provider.id) }
            }
            .buttonStyle(SecondaryButtonStyle(accent: accent))
        }
    }

    private var inlineErrorNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
            Text(noteText)
                .font(.system(size: 10))
        }
        .foregroundStyle(Theme.textTertiary)
    }

    private var noteText: String {
        if case .rateLimited = state.lastError {
            return "Showing cached data — retrying soon."
        }
        return "Showing last known data."
    }

    // MARK: - Sign-in

    @ViewBuilder private var signInView: some View {
        if let _ = pendingSubmit {
            pasteCodeView
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Not signed in")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 6) {
                        if isAuthenticating { ProgressView().controlSize(.small).scaleEffect(0.8) }
                        Text(isAuthenticating ? "Opening browser…" : "Sign in to \(provider.displayName)")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(accent: accent))
                .disabled(isAuthenticating)

                if let authError {
                    Text(authError)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.high)
                }
            }
        }
    }

    private var pasteCodeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pendingInstructions.isEmpty ? "Paste the code from your browser:" : pendingInstructions)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                TextField("code", text: $codeInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { submitCode() }
                Button("Submit") { submitCode() }
                    .buttonStyle(PrimaryButtonStyle(accent: accent))
                    .disabled(isAuthenticating || codeInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack(spacing: 12) {
                Button("Cancel") {
                    pendingSubmit = nil
                    codeInput = ""
                    authError = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                if isAuthenticating { ProgressView().controlSize(.small).scaleEffect(0.7) }
            }
            if let authError {
                Text(authError)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.high)
            }
        }
    }

    // MARK: - Actions

    private func authenticate() {
        authError = nil
        isAuthenticating = true
        Task {
            do {
                let continuation = try await store.startSignIn(provider.id)
                switch continuation {
                case .completed:
                    pendingSubmit = nil
                case .needsCode(let instructions, let submit):
                    pendingInstructions = instructions
                    pendingSubmit = submit
                }
            } catch {
                authError = friendly(error)
            }
            isAuthenticating = false
        }
    }

    private func submitCode() {
        guard let submit = pendingSubmit else { return }
        let code = codeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isAuthenticating = true
        authError = nil
        Task {
            do {
                try await submit(code)
                pendingSubmit = nil
                codeInput = ""
                await store.finishSignIn(provider.id)
            } catch {
                authError = friendly(error)
            }
            isAuthenticating = false
        }
    }

    private func friendly(_ error: Error) -> String {
        if let providerError = error as? ProviderError {
            switch providerError {
            case .notSignedIn: return "Not signed in."
            case .unauthorized: return "Session expired — sign in again."
            case .rateLimited: return "Rate-limited. Try again later."
            case .transport(let message): return message
            case .decoding: return "Unexpected response from server."
            }
        }
        return error.localizedDescription
    }
}
