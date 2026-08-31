import SwiftUI
import FamilyControls

struct BlocksView: View {
    @Bindable var store: HabitStore
    @Bindable var blocks: BlockController
    @State private var addingHabit = false
    @State private var pickingFor: Habit?
    @State private var running: Habit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    if store.habits.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.habits) { habit in
                            HabitCard(habit: binding(for: habit),
                                      appCount: blocks.appCount(for: habit.id),
                                      onStart: { running = habit },
                                      onPickApps: { pickingFor = habit })
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        store.habits.removeAll { $0.id == habit.id }
                                    }
                                }
                        }
                    }
                }
                .padding(16)
            }
            .sheet(isPresented: $addingHabit) { AddHabitView(store: store) }
            .familyActivityPicker(
                isPresented: Binding(get: { pickingFor != nil },
                                     set: { if !$0 { pickingFor = nil } }),
                selection: Binding(
                    get: { pickingFor.map { blocks.selection(for: $0.id) } ?? .init() },
                    set: { if let h = pickingFor { blocks.selections[h.id] = $0 } }))
            .fullScreenCover(item: $running) { habit in
                SessionView(habit: habit) { store.log($0, for: habit) }
            }
        }
    }

    /// Binds by id, not by position: a card that outlives its habit reads a
    /// stale copy instead of an invalid index.
    private func binding(for habit: Habit) -> Binding<Habit> {
        Binding(
            get: { store.habits.first { $0.id == habit.id } ?? habit },
            set: { updated in
                guard let i = store.habits.firstIndex(where: { $0.id == updated.id }) else { return }
                store.habits[i] = updated
            }
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("IconMark")
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("habits first")
                .font(.system(.title, design: .monospaced).weight(.bold))
            Spacer()
            if !store.habits.isEmpty {
                Button { addingHabit = true } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                }
            }
        }
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Button { addingHabit = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 44, weight: .medium))
                    .frame(width: 130, height: 130)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            }
            Text("create your first habit!")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(.top, 120)
    }
}

private struct HabitCard: View {
    @Binding var habit: Habit
    let appCount: Int
    let onStart: () -> Void
    let onPickApps: () -> Void

    private var done: Bool { habit.isDone(on: Date()) }
    private var seconds: Int { habit.secondsLogged(on: Date()) }
    private var minutes: Int { seconds / 60 }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onPickApps) {
                    VStack(spacing: 2) {
                        Image(systemName: done ? "lock.open.fill" : "lock.fill")
                            .font(.title2)
                        Text(appCount == 0 ? "pick" : "\(appCount)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name).font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        chip("CONDITION")
                        chip("DAILY")
                        if habit.streak > 0 { chip("\(habit.streak)🔥") }
                    }
                }
                Spacer()
                Toggle("", isOn: $habit.isEnabled)
                    .labelsHidden()
                    .tint(.green)   // app tint is white; without this the knob vanishes into the track
            }

            Button(action: onStart) {
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
