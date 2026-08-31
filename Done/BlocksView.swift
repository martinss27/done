import SwiftUI

struct BlocksView: View {
    @Bindable var store: HabitStore
    @State private var addingHabit = false
    @State private var running: Habit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($store.habits) { $habit in
                        HabitCard(habit: $habit) { running = habit }
                    }
                    if store.habits.isEmpty {
                        ContentUnavailableView("Nenhum hábito",
                            systemImage: "shield",
                            description: Text("Toque em + para criar o primeiro."))
                            .padding(.top, 80)
                    }
                }
                .padding(16)
            }
            .navigationTitle("✏️ habits first")
            .toolbar {
                Button { addingHabit = true } label: {
                    Image(systemName: "plus").font(.headline)
                }
            }
            .sheet(isPresented: $addingHabit) { AddHabitView(store: store) }
            .fullScreenCover(item: $running) { habit in
                SessionView(habit: habit) { store.log($0, for: habit) }
            }
        }
    }
}

private struct HabitCard: View {
    @Binding var habit: Habit
    let onTap: () -> Void

    private var done: Bool { habit.isDone(on: Date()) }
    private var seconds: Int { habit.secondsLogged(on: Date()) }
    private var minutes: Int { seconds / 60 }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: done ? "lock.open.fill" : "lock.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name).font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        chip("CONDITION")
                        chip("DAILY")
                        if habit.streak > 0 { chip("\(habit.streak)🔥") }
                    }
                }
                Spacer()
                Toggle("", isOn: $habit.isEnabled).labelsHidden()
            }

            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundStyle(.cyan)
                    Text(habit.name).foregroundStyle(.primary)
                    Spacer()
                    Text("\(minutes) / \(habit.targetMinutes) min")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .disabled(done)

            ProgressView(value: Double(seconds), total: Double(habit.targetMinutes * 60))
                .tint(.cyan)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .opacity(habit.isEnabled ? 1 : 0.4)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
