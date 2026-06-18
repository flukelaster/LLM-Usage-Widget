import SwiftUI

/// A reset label that re-renders on a timeline so the countdown ticks without re-fetching.
struct CountdownText: View {
    let resetsAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(RelativeTime.resetLabel(resetsAt, from: context.date))
        }
    }
}
