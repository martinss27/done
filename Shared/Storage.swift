import Foundation

/// The app and the DeviceActivity extension are separate processes. Everything
/// either of them needs to read or write lives in the shared group container.
enum Storage {
    static let groupID = "group.com.martinss27.done"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    enum Key {
        static let habits = "habits"
        static let selections = "blockSelections"
        static let unlockSelections = "unlockSelections"
        static let focusAllowed = "focusAllowed"
        static let gate = "gate"
        static let diagnostics = "diagnostics"
        static let armed = "armed"
    }
}
