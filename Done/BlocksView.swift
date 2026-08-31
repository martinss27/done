import SwiftUI
import FamilyControls

struct BlocksView: View {
    @Bindable var store: HabitStore
    @Bindable var blocks: BlockController
    @State private var addingBlock = false
    @State private var editing: Habit?
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
                                      apps: blocks.selection(for: habit.id),
                                      unlocked: habit.isUnlocked(on: Date(), gate: blocks.gate),
                                      onStart: { running = habit },
                                      onEdit: { editing = habit })
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
            .sheet(isPresented: $addingBlock) { EditBlockView(store: store, blocks: blocks) }
            .sheet(item: $editing) { EditBlockView(store: store, blocks: blocks, editing: $0) }
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
            Text("it's done?")
                .font(.system(.title, design: .monospaced).weight(.bold))
            Spacer()
            if !store.habits.isEmpty {
                Button { addingBlock = true } label: {
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
            Button { addingBlock = true } label: {
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
    let apps: FamilyActivitySelection
    let unlocked: Bool
    let onStart: () -> Void
    let onEdit: () -> Void

    private var done: Bool { habit.isDone(on: Date()) }
    private var seconds: Int { habit.secondsLogged(on: Date()) }
    private var minutes: Int { seconds / 60 }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onEdit) { appIcons }
                    .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name).font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        chip("CONDITION")
                        chip(habit.days.count == 7 ? "DAILY" : "CUSTOM")
                        if habit.streak > 0 { chip("\(habit.streak)🔥") }
                    }
                    if !habit.cardDetail.isEmpty {
                        Text(habit.cardDetail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Toggle("", isOn: $habit.isEnabled)
                        .labelsHidden()
                        .tint(.green)   // app tint is white; without this the knob vanishes into the track
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if habit.timerMinutes != nil {
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
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .opacity(habit.isEnabled ? 1 : 0.4)
    }

    /// The apps this block covers, overlapping like a stack of cards. Tokens are
    /// opaque, so `Label` is the only way to draw an app we are not allowed to name.
    private var appIcons: some View {
        let tokens = Array(apps.applicationTokens.prefix(3))
        let extra = apps.applicationTokens.count - tokens.count + apps.categoryTokens.count
        return ZStack {
            if tokens.isEmpty {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: -10) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .scaleEffect(0.8)
                            .frame(width: 28, height: 28)
                    }
                    if extra > 0 {
                        Text("+\(extra)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .frame(width: 60, height: 60)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
