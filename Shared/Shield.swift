import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// The shield, computed from stored state alone so the app and the
/// DeviceActivity extension reach the same answer without talking to each other.
enum Shield {
    private static let store = ManagedSettingsStore()

    static var habits: [Habit] { Storage.load([Habit].self, Storage.Key.habits) ?? [] }

    /// Apps a block shields.
    static func blocked(_ id: UUID) -> FamilyActivitySelection {
        (Storage.load([UUID: FamilyActivitySelection].self, Storage.Key.selections) ?? [:])[id] ?? .init()
    }

    /// The app you have to use to earn the unlock.
    static func unlockApp(_ id: UUID) -> FamilyActivitySelection {
        (Storage.load([UUID: FamilyActivitySelection].self, Storage.Key.unlockSelections) ?? [:])[id] ?? .init()
    }

    /// Shields every app tied to a block whose conditions are not met yet.
    /// `focusAllow` non-nil means a pomodoro round is running: shield everything
    /// except the allowlist instead.
    static func apply(focusAllow: FamilyActivitySelection? = nil) {
        if let focusAllow {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: focusAllow.applicationTokens)
            return
        }
        let gate = Gate.current
        let pending = habits.filter { $0.isEnabled && !$0.isUnlocked(on: Date(), gate: gate) }
        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        for habit in pending {
            let selection = blocked(habit.id)
            apps.formUnion(selection.applicationTokens)
            categories.formUnion(selection.categoryTokens)
        }
        // Never shield the app you have to use to get out — that is a dead end.
        for habit in habits where habit.appTimeMinutes != nil {
            apps.subtract(unlockApp(habit.id).applicationTokens)
        }
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }
}

/// One DeviceActivity activity per block, so re-arming one block's counter never
/// resets another's.
extension DeviceActivityName {
    static func block(_ id: UUID) -> Self { Self("block-\(id.uuidString)") }
    var blockID: UUID? { UUID(uuidString: rawValue.replacingOccurrences(of: "block-", with: "")) }
}

extension DeviceActivityEvent.Name {
    static let earnUnlock = Self("earnUnlock")
    static let spendUnlock = Self("spendUnlock")
}

/// Starts, re-arms and stops the usage counters behind App time and
/// "Block again after".
enum Monitoring {
    private static let center = DeviceActivityCenter()

    /// Midnight to midnight, repeating: usage totals reset with the day.
    private static var daily: DeviceActivitySchedule {
        DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                               intervalEnd: DateComponents(hour: 23, minute: 59),
                               repeats: true)
    }

    /// Re-points one block's counter at whatever it is waiting for now: the
    /// unlock app while it still has to be earned, the blocked apps once open.
    /// Restarting is what resets the threshold, so this is also how a re-lock
    /// starts counting from zero rather than from the start of the day.
    static func arm(_ habit: Habit, unlocked: Bool) {
        let name = DeviceActivityName.block(habit.id)
        guard habit.isEnabled, let minutes = habit.appTimeMinutes else {
            center.stopMonitoring([name])
            clearArmed(habit.id)
            return
        }

        // Restarting an activity resets the minutes it has counted, so a block
        // already armed for exactly this must be left alone — otherwise every
        // trip through the app throws away the usage earned so far.
        let want = "\(unlocked)|\(minutes)|\(habit.blockAgainMinutes.map(String.init) ?? "-")|"
            + "\(Shield.unlockApp(habit.id).applicationTokens.count)|\(Shield.blocked(habit.id).applicationTokens.count)"
        if center.activities.contains(name), armedState[habit.id] == want { return }
        center.stopMonitoring([name])

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if unlocked {
            guard let spend = habit.blockAgainMinutes else { return }
            let apps = Shield.blocked(habit.id)
            events[.spendUnlock] = DeviceActivityEvent(applications: apps.applicationTokens,
                                                       categories: apps.categoryTokens,
                                                       threshold: DateComponents(minute: spend))
        } else {
            let apps = Shield.unlockApp(habit.id)
            guard !apps.applicationTokens.isEmpty || !apps.categoryTokens.isEmpty else { return }
            events[.earnUnlock] = DeviceActivityEvent(applications: apps.applicationTokens,
                                                      categories: apps.categoryTokens,
                                                      threshold: DateComponents(minute: minutes))
        }
        do {
            try center.startMonitoring(name, during: daily, events: events)
            setArmed(habit.id, want)
            Diagnostics.log("armed \(habit.name): \(events.keys.map(\.rawValue).joined(separator: ",")) "
                            + "apps=\((unlocked ? Shield.blocked(habit.id) : Shield.unlockApp(habit.id)).applicationTokens.count)")
        } catch {
            clearArmed(habit.id)
            Diagnostics.log("ARM FAILED \(habit.name): \(error)")
        }
    }

    /// What each block is currently armed for, so a re-arm that would change
    /// nothing can be skipped.
    private static var armedState: [UUID: String] {
        Storage.load([UUID: String].self, Storage.Key.armed) ?? [:]
    }
    private static func setArmed(_ id: UUID, _ value: String) {
        var all = armedState; all[id] = value; Storage.save(all, Storage.Key.armed)
    }
    private static func clearArmed(_ id: UUID) {
        var all = armedState; all[id] = nil; Storage.save(all, Storage.Key.armed)
    }

    /// Names of the activities the system is currently counting for us.
    static var active: [String] { center.activities.map(\.rawValue) }

    /// Drops a block's counter without re-arming it.
    static func stop(_ id: UUID) {
        center.stopMonitoring([DeviceActivityName.block(id)])
        clearArmed(id)
    }

    /// Brings every block's counter in line with the state it is in, and drops
    /// counters left behind by blocks that no longer exist.
    static func armAll() {
        let gate = Gate.current
        let live = Set(Shield.habits.map(\.id))
        let stale = center.activities.filter { $0.blockID.map { !live.contains($0) } ?? true }
        if !stale.isEmpty { center.stopMonitoring(stale) }
        for habit in Shield.habits {
            arm(habit, unlocked: gate.open.contains(habit.id))
        }
    }
}
