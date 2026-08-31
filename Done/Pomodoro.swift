import Foundation

enum PomodoroPhase: String {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "focus"
        case .shortBreak: "short break"
        case .longBreak: "long break"
        }
    }

    var isBreak: Bool { self != .focus }
}

/// Breaks always hand back to focus. A finished focus earns the long break on
/// every `longBreakEvery`-th round, the short one otherwise.
/// `completedFocuses` counts the round that just ended.
func nextPhase(after phase: PomodoroPhase, completedFocuses: Int, longBreakEvery: Int = 4) -> PomodoroPhase {
    guard phase == .focus else { return .focus }
    return completedFocuses % max(longBreakEvery, 1) == 0 ? .longBreak : .shortBreak
}
