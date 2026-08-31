import ActivityKit
import Foundation

/// The round, as the lock screen sees it. The end date is all the widget needs:
/// `Text(timerInterval:)` counts down on its own, so a running round costs no
/// updates and keeps ticking while the app is suspended.
struct FocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
        var phase: String
    }
}
