import Foundation
import Observation

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var targetMinutes: Int
    var streak: Int = 0
    var lastDone: Date? = nil

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

    func complete(_ habit: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[i] = habits[i].completed(on: Date())
    }
}
