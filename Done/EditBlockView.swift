import SwiftUI
import FamilyControls

/// Create or edit one block: the apps it locks, what unlocks them, and the days
/// it runs. Edits a copy so Cancel really cancels.
struct EditBlockView: View {
    @Bindable var store: HabitStore
    @Bindable var blocks: BlockController
    /// nil creates a new block.
    let editing: Habit?
    @Environment(\.dismiss) private var dismiss

    @State private var habit: Habit
    @State private var apps = FamilyActivitySelection()
    @State private var pickingApps = false
    @State private var showingDays = false
    @State private var unlockApps = FamilyActivitySelection()
    @State private var pickingUnlockApp = false
    @State private var customFor: String?
    @State private var customText = ""

    init(store: HabitStore, blocks: BlockController, editing: Habit? = nil) {
        self.store = store
        self.blocks = blocks
        self.editing = editing
        _habit = State(initialValue: editing ?? Habit(name: ""))
        _apps = State(initialValue: editing.map { blocks.selection(for: $0.id) } ?? .init())
        _unlockApps = State(initialValue: editing.map { blocks.unlockSelection(for: $0.id) } ?? .init())
    }

    private var appCount: Int { apps.applicationTokens.count + apps.categoryTokens.count }
    private var canSave: Bool { !habit.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                VStack(spacing: 16) {
                    nameCard
                    appsCard
                    limitKindCard
                    conditionsCard
                    daysCard
                }
                .padding(16)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $pickingApps, selection: $apps)
        .familyActivityPicker(isPresented: $pickingUnlockApp, selection: $unlockApps)
    }

    private var bar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.white.opacity(0.08), in: Capsule())
            Spacer()
            Text(editing == nil ? "New block" : "Edit block").font(.title3.weight(.semibold))
            Spacer()
            Button("Save", action: save)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.white.opacity(0.08), in: Capsule())
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private var nameCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.fill")
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            TextField("Name this block", text: $habit.name)
                .font(.title2.weight(.bold))
        }
        .card()
    }

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("square.grid.2x2.fill", "Which apps do you want to limit?")
            Button { pickingApps = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: appCount > 0 ? "checkmark.seal.fill" : "plus.circle")
                    Text(appCount == 0 ? "Select apps"
                         : "\(appCount) app\(appCount == 1 ? "" : "s") selected")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .font(.body.weight(.medium))
                .padding(16)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var limitKindCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("clock.fill", "How do you want to limit them?")
            HStack(spacing: 10) {
                kindTab("key.fill", "Condition", active: true)
                kindTab("clock.fill", "Time", active: false)
                kindTab("mappin.and.ellipse", "Place", active: false)
                kindTab("dot.radiowaves.left.and.right", "Device", active: false)
            }
        }
        .card()
    }

    private func kindTab(_ icon: String, _ label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(label).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            if active {
                RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1.5)
            }
        }
        .foregroundStyle(active ? .white : .secondary)
    }

    private var conditionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("key.fill", "Select a habit to unlock your apps")

            conditionRow(kind: "steps", icon: "figure.walk", title: "Steps", tint: .blue,
                         presets: [5_000, 8_000, 10_000, 15_000],
                         label: { $0.compact },
                         make: { .steps(count: $0) },
                         value: { if case .steps(let n) = $0 { n } else { nil } })

            conditionRow(kind: "workout", icon: "figure.run", title: "Workout", tint: .orange,
                         presets: [15, 30, 45, 60],
                         label: { "\($0)" },
                         make: { .workout(minutes: $0) },
                         value: { if case .workout(let m) = $0 { m } else { nil } })

            conditionRow(kind: "mindful", icon: "brain.head.profile", title: "Meditate", tint: .purple,
                         presets: [5, 10, 15, 20],
                         label: { "\($0)" },
                         make: { .mindful(minutes: $0) },
                         value: { if case .mindful(let m) = $0 { m } else { nil } })

            conditionRow(kind: "appTime", icon: "timer.circle", title: "App time", tint: .green,
                         presets: [5, 10, 15, 30],
                         label: { "\($0)" },
                         make: { .appTime(minutes: $0) },
                         value: { if case .appTime(let m) = $0 { m } else { nil } },
                         extra: { AnyView(unlockAppPicker) })
            soonRow("scribble", "Shortcut")
            blockAgainRow

            if habit.conditions.isEmpty {
                Text("No conditions yet. Add one to earn unlocks.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .card()
        .alert("Custom goal", isPresented: Binding(get: { customFor != nil },
                                                   set: { if !$0 { customFor = nil } })) {
            TextField(Condition.unit(kind: customFor ?? "steps"), text: $customText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Set") {
                guard let kind = customFor, let n = Int(customText), n > 0,
                      let condition = Condition.make(kind: kind, value: n) else { return }
                set(kind: kind, to: condition)
            }
        }
    }

    /// Which app you have to use to earn the unlock. Shown under App time only.
    private var unlockAppPicker: some View {
        Button { pickingUnlockApp = true } label: {
            HStack(spacing: 12) {
                Image(systemName: unlockCount > 0 ? "checkmark.seal.fill" : "plus.circle")
                Text(unlockCount == 0 ? "Pick the app that unlocks"
                     : "\(unlockCount) app\(unlockCount == 1 ? "" : "s") to earn it")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(unlockCount > 0 ? Color.green : .secondary)
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var unlockCount: Int {
        unlockApps.applicationTokens.count + unlockApps.categoryTokens.count
    }

    /// Minutes of use after an unlock before the apps shield again. Only means
    /// anything once there is something to earn, so it stays off without one.
    private var blockAgainRow: some View {
        let available = habit.appTimeMinutes != nil
        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block again after")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(available ? .white : .secondary)
                    Text(available ? "minutes of use before it locks again"
                                   : "needs an App time condition above")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(habit.blockAgainMinutes.map { "\($0) min" } ?? "Off")
                    .font(.body.weight(.medium))
                    .foregroundStyle(habit.blockAgainMinutes == nil ? .secondary : Color.green)
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

            if available {
                HStack(spacing: 6) {
                    chipButton("Off", tint: .green, selected: habit.blockAgainMinutes == nil) {
                        habit.blockAgainMinutes = nil
                    }
                    ForEach([2, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        chipButton("\(minutes)", tint: .green,
                                   selected: habit.blockAgainMinutes == minutes) {
                            habit.blockAgainMinutes = minutes
                        }
                    }
                }
            }
        }
        .opacity(available ? 1 : 0.5)
    }

    /// One toggleable condition row plus its preset chips when it is on.
    /// The last chip opens a free-form goal instead of picking a preset.
    private func conditionRow(kind: String, icon: String, title: String,
                              tint: Color, presets: [Int],
                              label: @escaping (Int) -> String,
                              make: @escaping (Int) -> Condition,
                              value: @escaping (Condition) -> Int?,
                              extra: (() -> AnyView)? = nil) -> some View {
        let current = habit.conditions.first { $0.kind == kind }
        let amount = current.flatMap(value)
        let on = amount != nil
        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(on ? tint : .secondary)
                    .frame(width: 44, height: 44)
                    .background(on ? tint.opacity(0.25) : .white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    if let current {
                        Text(current.detail).font(.subheadline).foregroundStyle(tint.opacity(0.9))
                    }
                }
                Spacer()
                Button {
                    if on {
                        habit.conditions.removeAll { $0.kind == kind }
                    } else {
                        habit.conditions.append(make(presets[presets.count / 2]))
                    }
                } label: {
                    Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundStyle(on ? tint : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(on ? tint.opacity(0.12) : .white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: 16).stroke(tint, lineWidth: 1.5)
                }
            }

            if on {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        chipButton(label(preset), tint: tint, selected: amount == preset) {
                            set(kind: kind, to: make(preset))
                        }
                    }
                    // The custom slot keeps showing the goal it holds, and tapping
                    // it reopens the field to change it.
                    let custom = amount.flatMap { presets.contains($0) ? nil : $0 }
                    chipButton(custom.map(label) ?? "•••", tint: tint, selected: custom != nil) {
                        customText = custom.map(String.init) ?? ""
                        customFor = kind
                    }
                }
                if let extra { extra() }
            }
        }
    }

    private func chipButton(_ text: String, tint: Color, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(selected ? tint : .white.opacity(0.08), in: Capsule())
                .foregroundStyle(selected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func set(kind: String, to condition: Condition) {
        guard let i = habit.conditions.firstIndex(where: { $0.kind == kind }) else { return }
        habit.conditions[i] = condition
    }

    private func soonRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            Image(systemName: "plus.circle").font(.title2)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.secondary)
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation { showingDays.toggle() } } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                    Text(habit.days.count == 7 ? "Customize days (default is daily)" : dayLabel)
                        .font(.body.weight(.medium))
                    Spacer()
                    Image(systemName: showingDays ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showingDays {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        let on = habit.days.contains(day)
                        Button {
                            if on { habit.days.remove(day) } else { habit.days.insert(day) }
                        } label: {
                            Text(Self.dayNames[day - 1])
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(on ? Color.blue : .white.opacity(0.08), in: Capsule())
                                .foregroundStyle(on ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .card()
    }

    private static let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    private var dayLabel: String {
        habit.days.isEmpty ? "No days selected"
            : (1...7).filter { habit.days.contains($0) }.map { Self.dayNames[$0 - 1] }.joined(separator: " ")
    }

    private func save() {
        // SessionView still counts against targetMinutes; keep it in step.
        if let m = habit.timerMinutes { habit.targetMinutes = m }
        if let i = store.habits.firstIndex(where: { $0.id == habit.id }) {
            store.habits[i] = habit
        } else {
            store.habits.append(habit)
        }
        blocks.selections[habit.id] = apps
        blocks.unlockSelections[habit.id] = unlockApps
        dismiss()
    }
}

private extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}

private func sectionTitle(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: icon)
        Text(text).font(.subheadline.weight(.semibold))
    }
    .foregroundStyle(.secondary)
}
