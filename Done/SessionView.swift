import SwiftUI

/// Countdown for one habit session. ponytail: foreground-only timer.
/// Add background time tracking (and app shielding) when Family Controls lands.
struct SessionView: View {
    let habit: Habit
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var remaining: Int = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Text(habit.name).font(.title2)

            Text(format(remaining))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            if remaining == 0 {
                Button("Feito") { onFinish(); dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { remaining = habit.targetMinutes * 60 }
        .onReceive(tick) { _ in if remaining > 0 { remaining -= 1 } }
    }

    private func format(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
