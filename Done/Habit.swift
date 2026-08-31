import Foundation
import Observation

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var targetMinutes: Int
    var isEnabled: Bool = true
    var streak: Int = 0
    var lastDone: Date? = nil
    var progressSeconds: Int = 0
    var progressDay: Date? = nil

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
    }

    init(name: String, targetMinutes: Int) {
        self.name = name
        self.targetMinutes = targetMinutes
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

    private let url = URL.documentsDirectory.appending(path: "habits.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }

    private func save() {
        try? JSONEncoder().encode(habits).write(to: url)
    }

    func log(_ seconds: Int, for habit: Habit) {
        guard seconds > 0, let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[i] = habits[i].logging(seconds: seconds, on: Date())
    }
}
