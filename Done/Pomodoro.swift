import SwiftUI

enum PomodoroPhase: String {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "focus"
        case .shortBreak: "short break"
        case .longBreak: "long break"
        }
    }

    /// Tiles and the tally are too narrow for "short break".
    var label: String {
        switch self {
        case .focus: "focus"
        case .shortBreak: "short"
        case .longBreak: "long"
        }
    }

    /// Same colours as the tally dots, so the ring says which timer is running.
    var color: Color {
        switch self {
        case .focus: .white
        case .shortBreak: .green
        case .longBreak: .blue
        }
    }

    var isBreak: Bool { self != .focus }
}
