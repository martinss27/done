import SwiftUI
import FamilyControls

struct PomodoroView: View {
    @Bindable var store: HabitStore
    @Bindable var blocks: BlockController
    @Environment(\.scenePhase) private var scene

    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("shortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("longBreakMinutes") private var longBreakMinutes = 15

    // Persisted so a cold launch never leaves a shield up with no timer behind it.
    @AppStorage("pomoEndsAt") private var endsAt = 0.0      // 0 while paused
    @AppStorage("pomoRemaining") private var paused = 0     // seconds left when paused
    @AppStorage("pomoPhase") private var phaseRaw = PomodoroPhase.focus.rawValue
    @AppStorage("pomoRounds") private var completedFocuses = 0
    @AppStorage("pomoShorts") private var completedShorts = 0
    @AppStorage("pomoLongs") private var completedLongs = 0
    @AppStorage("pomoFocusSeconds") private var focusSeconds = 0
    @AppStorage("pomoShortSeconds") private var shortSeconds = 0
    @AppStorage("pomoLongSeconds") private var longSeconds = 0

    @State private var now = Date()
    @State private var picking = false
    @State private var alarmOn = true
    // iOS 26 rings a real alarm; older systems fall back to a notification.
    private var hasRealAlarm: Bool { if #available(iOS 26.0, *) { true } else { false } }
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var phase: PomodoroPhase { PomodoroPhase(rawValue: phaseRaw) ?? .focus }
    private var isRunning: Bool { endsAt > 0 }
    private var remaining: Int {
        isRunning ? max(Int(endsAt - now.timeIntervalSinceReferenceDate), 0) : paused
    }

    var body: some View {
        // Header inline rather than a navigation title, so "focus" sits at the
        // same height as "insights" one tab over.
        VStack(spacing: 0) {
            Text("focus")
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ScrollView {
                VStack(spacing: 24) {
                    dial
                    panel
                    tally
                }
                .padding(16)
            }
            .familyActivityPicker(isPresented: $picking, selection: $blocks.focusAllowed)
            .onAppear { if paused == 0 && !isRunning { paused = minutes(for: phase) * 60 } }
            .task { alarmOn = await alarmAllowed() }
            .onReceive(tick) { _ in
                guard isRunning else { return }
                now = Date()
                if remaining == 0 { if !hasRealAlarm { FocusAlarm.ring() }; complete() }
            }
            .onChange(of: scene) { if scene == .active { Task { alarmOn = await alarmAllowed() }; now = Date(); if isRunning && remaining == 0 { complete() } } }
            .onChange(of: focusMinutes) { resetIfIdle() }
            .onChange(of: shortBreakMinutes) { resetIfIdle() }
            .onChange(of: longBreakMinutes) { resetIfIdle() }
        }
    }

    private var dial: some View {
        VStack(spacing: 8) {
            if phase.isBreak {
                Text(phase.title)
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            Text(clock(remaining))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("round \(completedFocuses + (phase == .focus ? 1 : 0))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    /// One card: each timer owns its play/pause, its countdown and its length,
    /// so the row you press is the row you tune. Only one ever runs — while
    /// focus is going, the two breaks are dead, and the other way round.
    private var panel: some View {
        VStack(spacing: 0) {
            timerRow(.focus, $focusMinutes, 5...90, step: 5)
            Divider()
            timerRow(.shortBreak, $shortBreakMinutes, 1...30, step: 1)
            Divider()
            timerRow(.longBreak, $longBreakMinutes, 5...60, step: 5)
            Divider()
            alarmRow
            Divider()
            Button { picking = true } label: {
                HStack {
                    Text("Apps allowed in focus")
                    Spacer()
                    Text("\(blocks.focusAllowed.applicationTokens.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .disabled(!blocks.isAuthorized)
            .foregroundStyle(.white)
        }
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay(alignment: .bottom) {
            if !blocks.isAuthorized {
                Text("Grant Screen Time access in Settings to block apps during focus.")
                    .font(.caption).foregroundStyle(.secondary)
                    .offset(y: 34)
            }
        }
        .padding(.bottom, blocks.isAuthorized ? 0 : 34)
    }

    private func timerRow(_ row: PomodoroPhase, _ length: Binding<Int>, _ range: ClosedRange<Int>, step: Int) -> some View {
        let armed = row == phase
        let running = armed && isRunning
        let locked = isRunning && !armed
        return HStack(spacing: 12) {
            Button { toggle(row) } label: {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.1), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.body.weight(running ? .semibold : .regular))
                Text(clock(armed ? remaining : length.wrappedValue * 60))
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            // Retuning a row mid-round would move the finish line under you,
            // so the length only changes while that row is stopped.
            Stepper("", value: length, in: range, step: step)
                .labelsHidden()
                .disabled(running)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(locked ? Color.secondary : (row.isBreak ? .green : .white))
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// Same shape as the Insights legend: a dot, a label, a number per band.
    private var tally: some View {
        VStack(spacing: 10) {
            HStack {
                count(.white, "focus", completedFocuses, focusSeconds)
                count(.green, "short", completedShorts, shortSeconds)
                count(.blue, "long", completedLongs, longSeconds)
            }
            .padding(.vertical, 14)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

            Button("Reset rounds", systemImage: "arrow.counterclockwise") { resetRounds() }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .disabled(completedFocuses + completedShorts + completedLongs == 0)
        }
    }

    private func count(_ color: Color, _ label: String, _ value: Int, _ seconds: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            // Rounds vary in length, so the count alone does not say how long you sat there.
            Text(duration(seconds))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    /// A round that ends without a sound is a round you miss, so say plainly
    /// when the permission is missing instead of failing quietly.
    @ViewBuilder private var alarmRow: some View {
        if alarmOn {
            HStack {
                Label("Alarm on", systemImage: "bell.fill")
                Spacer()
            }
            .padding(12)
        } else {
            Button {
                Task {
                    if await requestAlarm() {
                        alarmOn = true
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            } label: {
                HStack {
                    Label(hasRealAlarm ? "Alarm off — tap to allow alarms"
                                      : "Alarm off — tap to allow notifications",
                          systemImage: "bell.slash")
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(12)
            }
        }
    }

    private func alarmAllowed() async -> Bool {
        if #available(iOS 26.0, *) { return RealAlarm.isAuthorized }
        return await FocusAlarm.isOn()
    }

    private func requestAlarm() async -> Bool {
        if #available(iOS 26.0, *) { return await RealAlarm.request() }
        return await FocusAlarm.request()
    }

    private func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    private func start() {
        if paused == 0 { paused = minutes(for: phase) * 60 }
        now = Date()
        endsAt = now.timeIntervalSinceReferenceDate + Double(paused)
        let ends = now.addingTimeInterval(Double(paused))
        let body = phase.isBreak ? "Break over — back to focus." : "Focus done — break, or another round?"
        if #available(iOS 26.0, *) {
            let seconds = Double(paused)
            let title = phase.title
            Task { await RealAlarm.start(seconds: seconds, phase: title, saying: body) }
        } else {
            FocusAlarm.arm(at: ends, saying: body)
            FocusLive.start(phase: phase.title, from: now, to: ends)
        }
        syncShields()
    }

    private func pause() {
        paused = remaining
        endsAt = 0
        stopAlarm()
        syncShields()
    }

    /// The play button on a row. A row already running pauses; any other row
    /// takes over, banking whatever time the old one had on the clock.
    private func toggle(_ row: PomodoroPhase) {
        guard !isRunning || row == phase else { return }   // one timer at a time
        if row == phase { isRunning ? pause() : start(); return }
        bankSpent()
        phaseRaw = row.rawValue
        paused = minutes(for: row) * 60
        start()
    }

    /// Time already on the clock is time you spent, so switching rows keeps
    /// the minutes and drops the leftover countdown. Only a timer that runs
    /// out earns a round.
    private func bankSpent() {
        add(seconds: max(minutes(for: phase) * 60 - remaining, 0), round: false)
        paused = minutes(for: phase) * 60
        endsAt = 0
        stopAlarm()
    }

    /// A timer that reaches zero counts its round and stops there. Nothing
    /// starts on its own — the next row is a tap away, and which one is yours.
    private func complete() {
        add(seconds: minutes(for: phase) * 60, round: true)
        paused = minutes(for: phase) * 60
        endsAt = 0
        stopAlarm()
        syncShields()
    }

    private func add(seconds: Int, round: Bool) {
        switch phase {
        case .focus: focusSeconds += seconds; if round { completedFocuses += 1 }
        case .shortBreak: shortSeconds += seconds; if round { completedShorts += 1 }
        case .longBreak: longSeconds += seconds; if round { completedLongs += 1 }
        }
    }

    /// Back to a clean first focus round, timer stopped and shields down.
    private func resetRounds() {
        completedFocuses = 0
        completedShorts = 0
        completedLongs = 0
        focusSeconds = 0
        shortSeconds = 0
        longSeconds = 0
        phaseRaw = PomodoroPhase.focus.rawValue
        paused = focusMinutes * 60
        endsAt = 0
        stopAlarm()
        syncShields()
    }

    private func resetIfIdle() {
        guard !isRunning else { return }
        paused = minutes(for: phase) * 60
    }

    private func stopAlarm() {
        if #available(iOS 26.0, *) { RealAlarm.stop() }
        FocusAlarm.disarm()
        FocusLive.end()
    }

    private func syncShields() {
        blocks.isFocusing = isRunning && phase == .focus
        blocks.focusEndsAt = blocks.isFocusing
            ? Date(timeIntervalSinceReferenceDate: endsAt) : nil
        blocks.apply(store.habits)
    }
}
