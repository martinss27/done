import Foundation
import Combine
import FamilyControls
import ManagedSettings
import Observation

/// Owns the Screen Time authorization and the app-side view of the shield.
/// App choices are opaque tokens: we can shield them, never read their names.
/// The state itself lives in the app group so the DeviceActivity extension
/// works from the same picture — see `Shield`.
@Observable
final class BlockController {
    var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var selections: [UUID: FamilyActivitySelection] = [:] { didSet { save() } }
    /// Per block, the app you have to use to earn the unlock.
    var unlockSelections: [UUID: FamilyActivitySelection] = [:] { didSet { saveUnlock() } }

    /// Apps that stay usable during a pomodoro focus round. Everything else is
    /// shielded while `isFocusing` — the inverse of the habit blocklist.
    var focusAllowed = FamilyActivitySelection() { didSet { saveAllowed() } }
    var isFocusing = false
    /// When the running focus round ends, shared so the shield can count it down.
    var focusEndsAt: Date?

    var gate = Gate.current

    /// Last known Health readings, refreshed by the app on every foreground.
    /// Kept here so `apply` has one shape for every caller — a pomodoro round
    /// re-applying the shield must not zero them out.
    var steps = 0
    var workoutMinutes = 0
    var mindfulMinutes = 0

    private var watch: AnyCancellable?

    var isAuthorized: Bool { status == .approved }

    init() {
        // The center resolves its status asynchronously, so a one-shot read at
        // launch reports .notDetermined even when access was already granted.
        watch = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.status = $0 }

        selections = Storage.load([UUID: FamilyActivitySelection].self, Storage.Key.selections)
            ?? Self.legacy(Storage.Key.selections) ?? [:]
        unlockSelections = Storage.load([UUID: FamilyActivitySelection].self,
                                        Storage.Key.unlockSelections) ?? [:]
        focusAllowed = Storage.load(FamilyActivitySelection.self, Storage.Key.focusAllowed)
            ?? Self.legacy(Storage.Key.focusAllowed) ?? FamilyActivitySelection()
    }

    /// One-time lift of state written before the app group existed.
    private static func legacy<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func requestAuthorization() async {
        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        status = AuthorizationCenter.shared.authorizationStatus
    }

    func selection(for id: UUID) -> FamilyActivitySelection { selections[id] ?? .init() }
    func unlockSelection(for id: UUID) -> FamilyActivitySelection { unlockSelections[id] ?? .init() }

    func appCount(for id: UUID) -> Int {
        let s = selection(for: id)
        return s.applicationTokens.count + s.categoryTokens.count
    }

    /// Recomputes which blocks their health conditions have satisfied, then
    /// re-applies the shield and re-points the usage counters.
    func apply(_ habits: [Habit]) {
        guard isAuthorized else { return }
        var gate = Gate.current
        if gate.rollOverIfNeeded() { Diagnostics.log("new day: unlocks reset") }
        gate.healthMet = Set(habits.filter {
            $0.healthMet(steps: steps, workoutMinutes: workoutMinutes, mindfulMinutes: mindfulMinutes)
        }.map(\.id))
        // A block with no app-time condition has nothing to earn or spend.
        let earners = Set(habits.filter { $0.appTimeMinutes != nil }.map(\.id))
        gate.banked.formIntersection(earners)
        gate.open.formIntersection(earners)
        gate.store()
        self.gate = gate

        FocusSession.store(isFocusing ? focusEndsAt.map(FocusSession.init) : nil)
        Shield.apply(focusAllow: isFocusing ? focusAllowed : nil)
        if !isFocusing { Monitoring.armAll() }
    }

    private func save() { Storage.save(selections, Storage.Key.selections) }
    private func saveUnlock() { Storage.save(unlockSelections, Storage.Key.unlockSelections) }
    private func saveAllowed() { Storage.save(focusAllowed, Storage.Key.focusAllowed) }
}
