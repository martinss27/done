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
    /// Blocks whose zone the phone is currently inside. Written by the app's
    /// geofence, which is the only thing that gets woken for a boundary cross.
    var inZone: Set<UUID> = []
    /// The day this state belongs to. Earned and spent unlocks do not carry over
    /// past midnight — a new day starts every block from scratch.
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

/// A pomodoro round in progress. Stored so the shield can say "finish your
/// round" instead of naming a habit that has nothing to do with why the app
/// is closed right now.
struct FocusSession: Codable, Equatable {
    var endsAt: Date

    var minutesLeft: Int {
        max(Int((endsAt.timeIntervalSinceNow / 60).rounded(.up)), 0)
    }

    /// nil once the round is over, so a stale entry cannot keep the copy wrong.
    static var current: FocusSession? {
        guard let session = Storage.load(FocusSession.self, Storage.Key.focus),
              session.endsAt > Date() else { return nil }
        return session
    }

    static func store(_ session: FocusSession?) {
        if let session { Storage.save(session, Storage.Key.focus) }
        else { Storage.defaults.removeObject(forKey: Storage.Key.focus) }
    }
}
