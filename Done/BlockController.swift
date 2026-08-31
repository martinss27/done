import Foundation
import Combine
import FamilyControls
import ManagedSettings
import Observation

/// Owns the Screen Time authorization and the shield state.
/// App choices are opaque tokens: we can shield them, never read their names.
@Observable
final class BlockController {
    var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var selections: [UUID: FamilyActivitySelection] = [:] { didSet { save() } }

    /// Apps that stay usable during a pomodoro focus round. Everything else is
    /// shielded while `isFocusing` — the inverse of the habit blocklist.
    var focusAllowed = FamilyActivitySelection() { didSet { saveAllowed() } }
    var isFocusing = false

    private let managed = ManagedSettingsStore()
    private let key = "blockSelections"
    private let allowKey = "focusAllowed"
    private var watch: AnyCancellable?

    var isAuthorized: Bool { status == .approved }

    init() {
        // The center resolves its status asynchronously, so a one-shot read at
        // launch reports .notDetermined even when access was already granted.
        watch = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.status = $0 }

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([UUID: FamilyActivitySelection].self, from: data) {
            selections = decoded
        }
        if let data = UserDefaults.standard.data(forKey: allowKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            focusAllowed = decoded
        }
    }

    func requestAuthorization() async {
        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        status = AuthorizationCenter.shared.authorizationStatus
    }

    func selection(for id: UUID) -> FamilyActivitySelection {
        selections[id] ?? FamilyActivitySelection()
    }

    func appCount(for id: UUID) -> Int {
        let s = selection(for: id)
        return s.applicationTokens.count + s.categoryTokens.count
    }

    /// Shields every app tied to a habit that is switched on and not done today.
    /// Finishing the habit drops it from the set, which unlocks its apps.
    /// A focus round overrides all of that: shield everything except the
    /// allowlist, so the one app you are focusing with is the only way out.
    func apply(_ habits: [Habit]) {
        guard isAuthorized else { return }
        if isFocusing {
            managed.shield.applications = nil
            managed.shield.applicationCategories = .all(except: focusAllowed.applicationTokens)
            return
        }
        let pending = habits.filter { $0.isEnabled && !$0.isDone(on: Date()) }
        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        for habit in pending {
            let s = selection(for: habit.id)
            apps.formUnion(s.applicationTokens)
            categories.formUnion(s.categoryTokens)
        }
        managed.shield.applications = apps.isEmpty ? nil : apps
        managed.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(selections) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func saveAllowed() {
        guard let data = try? JSONEncoder().encode(focusAllowed) else { return }
        UserDefaults.standard.set(data, forKey: allowKey)
    }
}
