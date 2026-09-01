import Foundation
import Observation

/// A slice of the day, in minutes from midnight. ponytail: same-day only —
/// a range that wraps past midnight is split by the user into two ranges.
struct TimeRange: Codable, Equatable, Identifiable {
    var id = UUID()
    var start: Int = 9 * 60
    var end: Int = 17 * 60

    var label: String {
        let d = Calendar.current.date(bySettingHour: start / 60, minute: start % 60, second: 0, of: Date())!
        let e = Calendar.current.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: Date())!
        return "\(d.formatted(date: .omitted, time: .shortened)) – \(e.formatted(date: .omitted, time: .shortened))"
    }
}

/// A circle on the map a block cares about. Whether being inside it locks or
/// unlocks the apps is `blockInside`.
struct Zone: Codable, Equatable {
    var name: String = ""
    var latitude: Double
    var longitude: Double
    /// Metres. CoreLocation ignores anything under ~50.
    var radius: Double = 50
    var blockInside: Bool = true
}

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var targetMinutes: Int
    var isEnabled: Bool = true
    var streak: Int = 0
    var lastDone: Date? = nil
    var progressSeconds: Int = 0
    var progressDay: Date? = nil

    /// What has to happen before the blocked apps open again. Empty means the
    /// block never locks anything — the edit screen says so.
    var conditions: [Condition] = []
    /// Weekdays the block is active, in `Calendar.component(.weekday)` terms (1 = Sunday).
    var days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    /// Minutes of use after an unlock before the apps shield again. nil = stays open.
    var blockAgainMinutes: Int? = nil
    /// Times of day the block applies. Empty means all day.
    var ranges: [TimeRange] = []
    /// true: the ranges are when the apps are blocked. false: the only times they are not.
    var blockDuring: Bool = true
    /// Where the block applies. nil means everywhere.
    var zone: Zone? = nil

    // Decode tolerantly so adding a field never wipes saved habits.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        targetMinutes = try c.decodeIfPresent(Int.self, forKey: .targetMinutes) ?? 5
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastDone = try c.decodeIfPresent(Date.self, forKey: .lastDone)
        progressSeconds = try c.decodeIfPresent(Int.self, forKey: .progressSeconds) ?? 0
        progressDay = try c.decodeIfPresent(Date.self, forKey: .progressDay)
        // Habits saved before conditions existed were all "run the timer".
        conditions = try c.decodeIfPresent([Condition].self, forKey: .conditions)
            ?? [.timer(minutes: targetMinutes)]
        days = try c.decodeIfPresent(Set<Int>.self, forKey: .days) ?? [1, 2, 3, 4, 5, 6, 7]
        blockAgainMinutes = try c.decodeIfPresent(Int.self, forKey: .blockAgainMinutes)
        ranges = try c.decodeIfPresent([TimeRange].self, forKey: .ranges) ?? []
        blockDuring = try c.decodeIfPresent(Bool.self, forKey: .blockDuring) ?? true
        zone = try c.decodeIfPresent(Zone.self, forKey: .zone)
    }

    init(name: String, targetMinutes: Int = 5, conditions: [Condition] = []) {
        self.name = name
        self.targetMinutes = targetMinutes
        self.conditions = conditions
    }

    var appTimeMinutes: Int? {
        conditions.compactMap { if case .appTime(let m) = $0 { m } else { nil } }.first
    }

    var timerMinutes: Int? {
        conditions.compactMap { if case .timer(let m) = $0 { m } else { nil } }.first
    }

    /// Seconds already logged for `day`. Progress from an earlier day does not carry over.
    func secondsLogged(on day: Date, calendar: Calendar = .current) -> Int {
        guard let progressDay, calendar.isDate(progressDay, inSameDayAs: day) else { return 0 }
        return progressSeconds
    }

    /// Adds time to today's tally, completing the habit once it reaches the target.
    func logging(seconds: Int, on day: Date, calendar: Calendar = .current) -> Habit {
        var copy = self
        copy.progressSeconds = min(secondsLogged(on: day, calendar: calendar) + max(seconds, 0), targetMinutes * 60)
        copy.progressDay = day
        if copy.progressSeconds >= targetMinutes * 60 {
            copy = copy.completed(on: day, calendar: calendar)
        }
        return copy
    }

    func isDone(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let lastDone else { return false }
        return calendar.isDate(lastDone, inSameDayAs: day)
    }

    /// Whether the block is in force at `date`. No ranges means all day; with
    /// ranges it is either only inside them or only outside them.
    func applies(at date: Date, calendar: Calendar = .current) -> Bool {
        guard !ranges.isEmpty else { return true }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let inside = ranges.contains { minute >= $0.start && minute < $0.end }
        return blockDuring ? inside : !inside
    }

    /// Whether the block is in force where the phone is. Only the app can see
    /// that, so the answer arrives through the gate.
    func appliesHere(gate: Gate) -> Bool {
        guard let zone else { return true }
        let inside = gate.inZone.contains(id)
        return zone.blockInside ? inside : !inside
    }

    func runs(on day: Date, calendar: Calendar = .current) -> Bool {
        days.contains(calendar.component(.weekday, from: day))
    }

    /// Whether the apps behind this block are open right now. A day the block
    /// does not run on, and a block with nothing to earn, are always unlocked.
    /// Health and app-time answers come from `gate` because the two processes
    /// that can measure them are not the one asking.
    func isUnlocked(on day: Date, gate: Gate, calendar: Calendar = .current) -> Bool {
        guard runs(on: day, calendar: calendar), applies(at: day, calendar: calendar),
              appliesHere(gate: gate) else { return true }
        return conditions.allSatisfy { condition in
            switch condition {
            case .timer: isDone(on: day, calendar: calendar)
            case .steps, .workout, .mindful: gate.healthMet.contains(id)
            case .appTime: gate.open.contains(id)
            }
        }
    }

    /// Evaluated by the app only: HealthKit is not reachable from the extension.
    func healthMet(steps: Int, workoutMinutes: Int, mindfulMinutes: Int) -> Bool {
        conditions.allSatisfy { condition in
            switch condition {
            case .steps(let target): steps >= target
            case .workout(let target): workoutMinutes >= target
            case .mindful(let target): mindfulMinutes >= target
            case .timer, .appTime: true
            }
        }
    }

    /// Marks the habit complete for `day`. Consecutive days extend the streak,
    /// a gap resets it, and repeating the same day changes nothing.
    func completed(on day: Date, calendar: Calendar = .current) -> Habit {
        var copy = self
        if isDone(on: day, calendar: calendar) { return copy }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day)!
        copy.streak = (lastDone.map { calendar.isDate($0, inSameDayAs: yesterday) } ?? false) ? streak + 1 : 1
        copy.lastDone = day
        return copy
    }
}

/// ponytail: JSON file on disk. Swap for SwiftData only if habits gain relations or queries.
@Observable
final class HabitStore {
    var habits: [Habit] = [] { didSet { save() } }

    private static let legacy = URL.documentsDirectory.appending(path: "habits.json")

    init() {
        if let shared = Storage.load([Habit].self, Storage.Key.habits) {
            habits = shared
        } else if let data = try? Data(contentsOf: Self.legacy),
                  let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            // One-time lift out of the app's own container into the shared one.
            habits = decoded
        }
    }

    private func save() {
        Storage.save(habits, Storage.Key.habits)
    }

    func log(_ seconds: Int, for habit: Habit) {
        guard seconds > 0, let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[i] = habits[i].logging(seconds: seconds, on: Date())
    }
}

extension Habit {
    /// The line under the chips on a block card: what it asks and what it pays.
    var cardDetail: String {
        var parts = conditions.map(\.detail)
        if let spend = blockAgainMinutes { parts.append("\(spend) min per unlock") }
        parts.append(contentsOf: scheduleDetail.map { [$0] } ?? [])
        if let zone { parts.append(zone.blockInside ? "at \(zone.name)" : "away from \(zone.name)") }
        return parts.joined(separator: " · ")
    }

    /// The hours the block covers, once it is not simply all day.
    var scheduleDetail: String? {
        guard !ranges.isEmpty else { return nil }
        let list = ranges.map(\.label).joined(separator: ", ")
        return blockDuring ? list : "all day except \(list)"
    }

    /// One sentence for the shield: what this block wants before it opens.
    var shieldSubtitle: String {
        let asks = conditions.map { condition -> String in
            switch condition {
            case .steps(let n):
                "walk \(n.formatted(.number.grouping(.automatic))) steps"
            case .workout(let m):
                "finish a \(m) min workout"
            case .mindful(let m):
                "meditate for \(m) min"
            case .timer(let m):
                "focus for \(m) min"
            case .appTime(let m):
                "use \(name) for \(m) min"
            }
        }
        guard !asks.isEmpty else {
            if let schedule = scheduleDetail { return "This block runs \(schedule)." }
            return "Open Done to set this block up."
        }
        let list = asks.count == 1 ? asks[0]
            : asks.dropLast().joined(separator: ", ") + " and " + asks[asks.count - 1]
        let sentence = list.prefix(1).uppercased() + list.dropFirst()
        if let spend = blockAgainMinutes, appTimeMinutes != nil {
            return "\(sentence) to bank a \(spend)-min unlock."
        }
        return "\(sentence) to unlock."
    }
}
