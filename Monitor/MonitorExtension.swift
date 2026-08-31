import DeviceActivity
import Foundation

/// Runs outside the app, woken by the system when a usage threshold is crossed.
/// It is the only thing that can see how long an app was used, so it owns the
/// app-time half of the gate.
final class MonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        Diagnostics.log("threshold \(event.rawValue) on \(activity.rawValue)")
        guard let id = activity.blockID,
              let habit = Shield.habits.first(where: { $0.id == id }) else {
            Diagnostics.log("  no block matched")
            return
        }

        var gate = Gate.current
        switch event {
        case .earnUnlock:
            // Earned it. The shield stays up — the unlock is banked until the
            // shield's own button spends it.
            gate.banked.insert(id)
            gate.store()
            Diagnostics.log("  banked an unlock for \(habit.name)")
            // Nothing left to count until it is spent.
            Monitoring.stop(habit.id)
        case .spendUnlock:
            // Burned through it: shield again and make the next one cost the
            // same work.
            gate.open.remove(id)
            gate.store()
            Shield.apply()
            Monitoring.arm(habit, unlocked: false)
        default:
            break
        }
    }

    /// Fires on every re-arm, not only at midnight, so it must not touch the
    /// gate — the app rolls the day over instead.
    override func intervalDidStart(for activity: DeviceActivityName) {
        Diagnostics.log("intervalDidStart \(activity.rawValue)")
    }
}
