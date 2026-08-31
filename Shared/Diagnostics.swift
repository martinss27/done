import Foundation

/// A short shared log. The app cannot watch the DeviceActivity extension run,
/// so both processes write here and Settings shows what actually happened.
enum Diagnostics {
    static func log(_ message: String) {
        var lines = Storage.load([String].self, Storage.Key.diagnostics) ?? []
        lines.insert("\(Date().formatted(date: .omitted, time: .standard))  \(message)", at: 0)
        Storage.save(Array(lines.prefix(30)), Storage.Key.diagnostics)
    }

    static var lines: [String] { Storage.load([String].self, Storage.Key.diagnostics) ?? [] }

    static func clear() { Storage.save([String](), Storage.Key.diagnostics) }
}
