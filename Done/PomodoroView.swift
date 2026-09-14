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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 24) {
                    dial
                    playButton
                    VStack(spacing: 12) {
                        tiles
                        if !blocks.isAuthorized {
                            Text("Grant Screen Time access in Settings to block apps during focus.")
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        tally
                    }
                    .padding(.top, 4)
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

    /// Same size and spacing as the Insights header, so "focus" sits where
    /// "insights" does one tab over. Apps and alarm live up here as status,
    /// out of the way of the timer.
    private var header: some View {
        HStack(spacing: 10) {
            Text("focus").font(.title2.weight(.bold))
            Spacer(minLength: 8)
            Button { picking = true } label: {
                Label("\(blocks.focusAllowed.applicationTokens.count)", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .disabled(!blocks.isAuthorized)
            .accessibilityLabel("Apps allowed in focus")
            .accessibilityValue("\(blocks.focusAllowed.applicationTokens.count)")
            alarmButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// The ring drains as the round runs, in the colour of the running timer.
    private var dial: some View {
        let total = max(minutes(for: phase) * 60, 1)
        return ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: Double(remaining) / Double(total))
                .stroke(phase.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            VStack(spacing: 2) {
                Text(phase.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(phase.isBreak ? phase.color : Color.secondary)
                Text(clock(remaining))
                    .font(.system(size: 60, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("round \(completedFocuses + (phase == .focus ? 1 : 0))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 236, height: 236)
        .padding(.top, 12)
    }

    private var playButton: some View {
        Button { isRunning ? pause() : start() } label: {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 30))
                .foregroundStyle(.black)
                .frame(width: 76, height: 76)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Pause" : "Start \(phase.title)")
    }

    /// Pick a timer and tune its length. Only one ever runs, so while one is
    /// going the other two fade and can't be picked.
    private var tiles: some View {
        HStack(spacing: 6) {
            tile(.focus, $focusMinutes, 5...90, step: 5)
            tile(.shortBreak, $shortBreakMinutes, 1...30, step: 1)
            tile(.longBreak, $longBreakMinutes, 5...60, step: 5)
        }
        .padding(6)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 20))
    }

    private func tile(_ row: PomodoroPhase, _ length: Binding<Int>, _ range: ClosedRange<Int>, step: Int) -> some View {
        let armed = row == phase
        let running = armed && isRunning
        let locked = isRunning && !armed
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(row.color).frame(width: 8, height: 8)
                Text(row.label)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(armed ? .primary : .secondary)
            // Retuning a row mid-round would move the finish line under you,
            // so the length only changes while that row is stopped.
            HStack(spacing: 2) {
                nudge("minus", length, by: -step, in: range, frozen: running)
                Text("\(length.wrappedValue)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                nudge("plus", length, by: step, in: range, frozen: running)
            }
            Text("min").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(armed ? Color.white.opacity(0.1) : .clear, in: .rect(cornerRadius: 15))
        .contentShape(.rect(cornerRadius: 15))
        .onTapGesture { select(row) }
        .accessibilityAction(named: "Select \(row.title)") { select(row) }
        .opacity(locked ? 0.45 : 1)
    }

    private func nudge(_ symbol: String, _ length: Binding<Int>, by step: Int, in range: ClosedRange<Int>, frozen: Bool) -> some View {
        let next = length.wrappedValue + step
        let enabled = !frozen && range.contains(next)
        return Button { length.wrappedValue = next } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(enabled ? .primary : .tertiary)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.08), in: Circle())
                .frame(width: 34, height: 34)   // bigger hit area than the circle
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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

    /// A round that ends without a sound is a round you miss, so the bell
    /// turns orange and asks for the permission instead of failing quietly.
    private var alarmButton: some View {
        Button {
            Task {
                if await requestAlarm() {
                    alarmOn = true
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            }
        } label: {
            Image(systemName: alarmOn ? "bell.fill" : "bell.slash")
                .font(.headline)
                .foregroundStyle(alarmOn ? Color.white : .orange)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.08), in: Circle())
        }
        .allowsHitTesting(!alarmOn)
        .accessibilityLabel(alarmOn ? "Alarm on"
                            : hasRealAlarm ? "Alarm off — tap to allow alarms"
                                           : "Alarm off — tap to allow notifications")
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

    /// Tapping a tile arms that timer without starting it — the big button
    /// starts it. Whatever the old one had on the clock is banked first.
    private func select(_ row: PomodoroPhase) {
        guard !isRunning, row != phase else { return }   // one timer at a time
        bankSpent()
        phaseRaw = row.rawValue
        paused = minutes(for: row) * 60
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
