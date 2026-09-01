import Foundation

/// One unlock requirement on a block. A block holds at most one of each kind —
/// the edit screen adds and removes them by kind, never duplicates.
enum Condition: Codable, Equatable, Identifiable {
    case timer(minutes: Int)
    case steps(count: Int)
    case workout(minutes: Int)
    case mindful(minutes: Int)
    /// Minutes spent in another app — the one you have to use to earn the unlock.
    case appTime(minutes: Int)

    var id: String { kind }

    var kind: String {
        switch self {
        case .timer: "timer"
        case .steps: "steps"
        case .workout: "workout"
        case .mindful: "mindful"
        case .appTime: "appTime"
        }
    }

    var title: String {
        switch self {
        case .timer: "Focus timer"
        case .steps: "Steps"
        case .workout: "Workout"
        case .mindful: "Meditate"
        case .appTime: "App time"
        }
    }

    var icon: String {
        switch self {
        case .timer: "timer"
        case .steps: "figure.walk"
        case .workout: "figure.run"
        case .mindful: "brain.head.profile"
        case .appTime: "timer.circle"
        }
    }

    /// Rebuilds a condition of the same kind with a new amount. The edit screen
    /// uses it for preset chips and the custom field alike.
    static func make(kind: String, value: Int) -> Condition? {
        switch kind {
        case "steps": .steps(count: value)
        case "workout": .workout(minutes: value)
        case "mindful": .mindful(minutes: value)
        case "appTime": .appTime(minutes: value)
        case "timer": .timer(minutes: value)
        default: nil
        }
    }

    /// What the custom field is asking for.
    static func unit(kind: String) -> String { kind == "steps" ? "Steps" : "Minutes" }

    /// True for the conditions HealthKit answers, which only the app can read.
    var isHealth: Bool {
        switch self {
        case .steps, .workout, .mindful: true
        case .timer, .appTime: false
        }
    }

    var minutes: Int? {
        switch self {
        case .timer(let m), .workout(let m), .mindful(let m), .appTime(let m): m
        case .steps: nil
        }
    }

    var detail: String {
        switch self {
        case .timer(let m): "\(m) min"
        case .steps(let n): "\(n.formatted(.number.grouping(.automatic))) steps"
        case .workout(let m): "\(m) min workout"
        case .mindful(let m): "\(m) min meditation"
        case .appTime(let m): "\(m) min in the app"
        }
    }
}

extension Int {
    /// Short form for chips: 235, 5k, 12.5k, 100k, 1.2M. Whole units drop the
    /// decimal so the common presets stay two characters wide.
    var compact: String {
        func trim(_ value: Double, _ suffix: String) -> String {
            let rounded = (value * 10).rounded() / 10
            return rounded == rounded.rounded()
                ? "\(Int(rounded))\(suffix)"
                : "\(rounded)\(suffix)"
        }
        switch abs(self) {
        case 1_000_000...: return trim(Double(self) / 1_000_000, "M")
        case 1_000...: return trim(Double(self) / 1_000, "k")
        default: return "\(self)"
        }
    }
}

extension Int {
    /// A span of seconds as the two largest units that carry information:
    /// 45s, 3m 20s, 1h 5m. Whole units drop the smaller half, and a short
    /// visit never collapses into a misleading "0m".
    var duration: String {
        if self < 60 { return "\(self)s" }
        if self < 3600 {
            let seconds = self % 60
            return seconds == 0 ? "\(self / 60)m" : "\(self / 60)m \(seconds)s"
        }
        let minutes = (self % 3600) / 60
        return minutes == 0 ? "\(self / 3600)h" : "\(self / 3600)h \(minutes)m"
    }
}
