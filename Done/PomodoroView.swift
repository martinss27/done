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

    @State private var now = Date()
    @State private var picking = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var phase: PomodoroPhase { PomodoroPhase(rawValue: phaseRaw) ?? .focus }
    private var isRunning: Bool { endsAt > 0 }
    private var remaining: Int {
        isRunning ? max(Int(endsAt - now.timeIntervalSinceReferenceDate), 0) : paused
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    dial
                    controls
                    settings
                }
                .padding(16)
            }
            .navigationTitle("focus")
            .familyActivityPicker(isPresented: $picking, selection: $blocks.focusAllowed)
            .onAppear { if paused == 0 && !isRunning { paused = minutes(for: phase) * 60 } }
            .onReceive(tick) { _ in
                guard isRunning else { return }
                now = Date()
                if remaining == 0 { advance() }
            }
            .onChange(of: scene) { if scene == .active { now = Date(); if isRunning && remaining == 0 { advance() } } }
            .onChange(of: focusMinutes) { resetIfIdle() }
            .onChange(of: shortBreakMinutes) { resetIfIdle() }
            .onChange(of: longBreakMinutes) { resetIfIdle() }
        }
    }

    private var dial: some View {
        VStack(spacing: 8) {
            Text(phase.title)
                .font(.headline)
                .foregroundStyle(phase.isBreak ? .green : .orange)
            Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("round \(completedFocuses + (phase == .focus ? 1 : 0))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(isRunning ? "Pause" : "Start") { isRunning ? pause() : start() }
                .buttonStyle(.borderedProminent)
            Button("Skip") { advance() }
                .buttonStyle(.bordered)
        }
        .tint(phase.isBreak ? .green : .orange)
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
        syncShields()
    }

    private func pause() {
        paused = remaining
        endsAt = 0
        syncShields()
    }

    /// Breaks and the next round start on a tap, never on their own: a phase
    /// that rolled over unattended could leave the shield up with nobody looking.
    /// ponytail: one hop per call — a session left running overnight resumes at
    /// the next phase, not wherever the full cycle would have landed.
    private func advance() {
        if phase == .focus { completedFocuses += 1 }
        phaseRaw = nextPhase(after: phase, completedFocuses: completedFocuses).rawValue
        paused = minutes(for: phase) * 60
        endsAt = 0
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
