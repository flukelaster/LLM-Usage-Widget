import SwiftUI

/// Process entry point. In DEBUG, `--snapshot <path>` renders the UI to a PNG and exits;
/// otherwise the normal menu-bar app launches.
@main
enum AppMain {
    static func main() {
        #if DEBUG
        let args = CommandLine.arguments
        if args.contains("--check") {
            let failures = MainActor.assumeIsolated { runSelfChecks() }
            exit(failures == 0 ? 0 : 1)
        }
        if let index = args.firstIndex(of: "--snapshot-states"), index + 1 < args.count {
            MainActor.assumeIsolated {
                SnapshotRunner.renderStatesSync(outputPath: args[index + 1])
            }
            return
        }
        if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
            MainActor.assumeIsolated {
                SnapshotRunner.renderSync(outputPath: args[index + 1])
            }
            return
        }
        #endif
        UsageWidgetApp.main()
    }
}
