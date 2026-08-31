import Foundation
import FamilyControls
import ManagedSettings
import Observation

/// Owns the Screen Time authorization and the shield state.
/// App choices are opaque tokens: we can shield them, never read their names.
@Observable
final class BlockController {
    var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var selections: [UUID: FamilyActivitySelection] = [:] { didSet { save() } }

    private let managed = ManagedSettingsStore()
    private let key = "blockSelections"

    var isAuthorized: Bool { status == .approved }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([UUID: FamilyActivitySelection].self, from: data) {
            selections = decoded
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
    func apply(_ habits: [Habit]) {
        guard isAuthorized else { return }
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
}
