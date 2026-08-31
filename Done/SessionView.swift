import SwiftUI

/// Counts down what is left of today's target and reports the time actually
/// spent, so a session you abandon halfway still counts.
/// ponytail: foreground-only. Add background time when Family Controls lands.
struct SessionView: View {
    let habit: Habit
    let onLog: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var remaining = 0
    @State private var elapsed = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Text(habit.name).font(.title2)

            Text(format(remaining))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            if remaining == 0 {
                Text("feito 🔥").font(.headline).foregroundStyle(.green)
                Button("Fechar") { dismiss() }.buttonStyle(.borderedProminent)
            } else {
                Button("Pausar") { dismiss() }.foregroundStyle(.secondary)
            }
        }
        .onAppear {
            remaining = max(habit.targetMinutes * 60 - habit.secondsLogged(on: Date()), 0)
        }
        .onReceive(tick) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            elapsed += 1
        }
        .onDisappear { onLog(elapsed) }
    }

    private func format(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
