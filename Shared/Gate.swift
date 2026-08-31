import Foundation

/// Which blocks are currently open, and why. The app owns the health half (it
/// is the only process that can read HealthKit); the DeviceActivity extension
/// owns the app-time half. Neither writes the other's field.
struct Gate: Codable, Equatable {
    /// Blocks whose health conditions are all met right now.
    var healthMet: Set<UUID> = []
    /// Blocks that earned an unlock and have not spent it yet. The shield stays
    /// up while one is banked — you still have to choose to spend it.
    /// ponytail: one at a time. Make it a count if banking several ever matters.
    var banked: Set<UUID> = []
    /// Blocks whose apps are open right now, burning the unlock they spent.
    var open: Set<UUID> = []
    /// The day this state belongs to. Earned and spent unlocks do not carry over.
    var day: Date?

    /// Clears yesterday's unlocks. Called by the app, not by interval callbacks:
    /// those fire on every re-arm, not only at midnight.
    mutating func rollOverIfNeeded(_ now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if let day, calendar.isDate(day, inSameDayAs: now) { return false }
        banked = []
        open = []
        day = now
        return true
    }

    static var current: Gate { Storage.load(Gate.self, Storage.Key.gate) ?? Gate() }
    func store() { Storage.save(self, Storage.Key.gate) }
}
