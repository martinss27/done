import SwiftUI
import DeviceActivity

// Shared by the app (which asks for the report) and the extension (which draws it).
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}
