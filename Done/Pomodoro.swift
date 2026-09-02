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

