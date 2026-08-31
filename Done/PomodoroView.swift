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
                    controls
                    settings
                    tally
                }
                .padding(16)
            }
            .familyActivityPicker(isPresented: $picking, selection: $blocks.focusAllowed)
            .onAppear { if paused == 0 && !isRunning { paused = minutes(for: phase) * 60 } }
            .onReceive(tick) { _ in
                guard isRunning else { return }
                now = Date()
                if remaining == 0 { FocusAlarm.ring(); advance() }
            }
            .onChange(of: scene) { if scene == .active { now = Date(); if isRunning && remaining == 0 { advance() } } }
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
            Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("round \(completedFocuses + (phase == .focus ? 1 : 0))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            // Black label: the prominent button is filled with the phase tint,
            // and white on white was invisible.
            Button { isRunning ? pause() : start() } label: {
                Text(isRunning ? "Pause" : "Start").foregroundStyle(.black)
            }
            .buttonStyle(.borderedProminent)
            Button("Skip") { advance() }
                .buttonStyle(.bordered)
        }
        .tint(phase.isBreak ? .green : .white)
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

    private var settings: some View {
        VStack(spacing: 0) {
            stepper("Focus", $focusMinutes, 5...90, step: 5)
            Divider()
            stepper("Short break", $shortBreakMinutes, 1...30, step: 1)
            Divider()
            stepper("Long break", $longBreakMinutes, 5...60, step: 5)
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
        }
        .foregroundStyle(.white)
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

    private func stepper(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) min").foregroundStyle(.secondary)
            }
        }
        .padding(12)
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
        FocusAlarm.arm(at: ends,
                       saying: phase.isBreak ? "Break over — back to focus." : "Focus done — take a break.")
        FocusLive.start(phase: phase.title, from: now, to: ends)
        syncShields()
    }

    private func pause() {
        paused = remaining
        endsAt = 0
        FocusAlarm.disarm()
        FocusLive.end()
        syncShields()
    }

    /// Breaks and the next round start on a tap, never on their own: a phase
    /// that rolled over unattended could leave the shield up with nobody looking.
    /// ponytail: one hop per call — a session left running overnight resumes at
    /// the next phase, not wherever the full cycle would have landed.
    private func advance() {
        let spent = max(minutes(for: phase) * 60 - remaining, 0)
        switch phase {
        case .focus: completedFocuses += 1; focusSeconds += spent
        case .shortBreak: completedShorts += 1; shortSeconds += spent
        case .longBreak: completedLongs += 1; longSeconds += spent
        }
        phaseRaw = nextPhase(after: phase, completedFocuses: completedFocuses).rawValue
        paused = minutes(for: phase) * 60
        endsAt = 0
        FocusAlarm.disarm()   // Skip mid-round: the old alarm must not still fire
        FocusLive.end()
        syncShields()
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
        FocusAlarm.disarm()
        FocusLive.end()
        syncShields()
    }

    private func resetIfIdle() {
        guard !isRunning else { return }
        paused = minutes(for: phase) * 60
    }

    private func syncShields() {
        blocks.isFocusing = isRunning && phase == .focus
        blocks.apply(store.habits)
    }
}
