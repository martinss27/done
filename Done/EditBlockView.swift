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
    /// Which "how do you want to limit them?" tab is showing.
    @State private var kind = "condition"
    @State private var pickingZone = false
    @State private var customFor: String?
    @State private var customText = ""

    init(store: HabitStore, blocks: BlockController, editing: Habit? = nil) {
        self.store = store
        self.blocks = blocks
        self.editing = editing
        _habit = State(initialValue: editing ?? Habit(name: ""))
        _apps = State(initialValue: editing.map { blocks.selection(for: $0.id) } ?? .init())
        _unlockApps = State(initialValue: editing.map { blocks.unlockSelection(for: $0.id) } ?? .init())
        if editing?.zone != nil { _kind = State(initialValue: "place") }
        else { _kind = State(initialValue: editing?.ranges.isEmpty == false ? "time" : "condition") }
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
                    switch kind {
                    case "time": timeCard
                    case "place": placeCard
                    default: conditionsCard
                    }
                    daysCard
                }
                .padding(16)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .familyActivityPicker(isPresented: $pickingApps, selection: $apps)
        .familyActivityPicker(isPresented: $pickingUnlockApp, selection: $unlockApps)
        .fullScreenCover(isPresented: $pickingZone) { ZonePickerView(zone: $habit.zone) }
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
                Button { kind = "condition" } label: { kindTab("key.fill", "Condition", active: kind == "condition") }
                Button { pickTime() } label: { kindTab("clock.fill", "Time", active: kind == "time") }
                Button { pickPlace() } label: { kindTab("mappin.and.ellipse", "Place", active: kind == "place") }
            }
            .buttonStyle(.plain)
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

    /// The Time tab starts with the range the reference app shows by default.
    private func pickTime() {
        kind = "time"
        if habit.ranges.isEmpty { habit.ranges = [TimeRange()] }
    }

    /// Opening Place with nothing set yet goes straight to the map, the way the
    /// tab reads: pick the place.
    private func pickPlace() {
        kind = "place"
        if habit.zone == nil { pickingZone = true }
    }

    private var placeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("mappin.and.ellipse", "Where should this block apply?")
            Button { pickingZone = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: habit.zone == nil ? "plus.circle" : "mappin.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.zone.map { $0.name.isEmpty ? "Unnamed place" : $0.name }
                             ?? "Choose a place")
                            .font(.body.weight(.medium))
                        if let zone = habit.zone {
                            Text("\(Int(zone.radius))m · "
                                 + (zone.blockInside ? "blocked here" : "the only place they open"))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if habit.zone != nil {
                Button("Remove this place") { habit.zone = nil }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("clock.fill", "Use the apps you selected on a schedule")

            ForEach(habit.ranges.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    timeChip($habit.ranges[i].start)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    timeChip($habit.ranges[i].end)
                    Spacer()
                    if habit.ranges.count > 1 {
                        Button { habit.ranges.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }

            Button { habit.ranges.append(TimeRange()) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add range").font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                modeTab("Block during", on: habit.blockDuring)
                modeTab("Unblock during", on: !habit.blockDuring)
            }
            .padding(4)
            .background(.white.opacity(0.07), in: Capsule())

            Text(habit.blockDuring ? "Apps are blocked during these times."
                 : "Apps are blocked all day EXCEPT during these times.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            if habit.ranges.contains(where: { $0.end - $0.start < 15 }) {
                Text("A range shorter than 15 minutes is ignored by iOS.")
                    .font(.footnote).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private func timeChip(_ minutes: Binding<Int>) -> some View {
        DatePicker("", selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                         minute: minutes.wrappedValue % 60, second: 0, of: Date())! },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }), displayedComponents: .hourAndMinute)
            .labelsHidden()
    }

    private func modeTab(_ title: String, on: Bool) -> some View {
        Button { habit.blockDuring = (title == "Block during") } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(on ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: Capsule())
                .foregroundStyle(on ? .white : .secondary)
        }
        .buttonStyle(.plain)
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
