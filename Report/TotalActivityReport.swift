import DeviceActivity
import ManagedSettings
import SwiftUI

struct AppRow: Identifiable {
    let id: String
    let token: ApplicationToken?
    let name: String
    let seconds: Int
    let pickups: Int

    /// How long a visit lasts on average. Short visits repeated all day are the
    /// compulsive pattern; the raw pickup count alone cannot tell them apart
    /// from an app you simply open a lot on purpose.
    var secondsPerPickup: Int { pickups > 0 ? seconds / pickups : seconds }
}

struct ActivityModel {
    var totalSeconds = 0
    var pickups = 0
    var apps: [AppRow] = []
}

/// Screen Time data may only be read inside this extension, and only ever
/// rendered — the numbers never cross back into the app process.
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityModel) -> ActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityModel {
        var total = 0.0
        var pickups = 0
        var byApp: [String: (token: ApplicationToken?, name: String, seconds: Double, pickups: Int)] = [:]

        for await result in data {
            for await segment in result.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let info = app.application
                        let key = info.bundleIdentifier ?? info.localizedDisplayName ?? UUID().uuidString
                        pickups += app.numberOfPickups
                        byApp[key] = (info.token,
                                      info.localizedDisplayName ?? "App",
                                      (byApp[key]?.seconds ?? 0) + app.totalActivityDuration,
                                      (byApp[key]?.pickups ?? 0) + app.numberOfPickups)
                    }
                }
            }
        }

        let apps = byApp
            .map { AppRow(id: $0.key, token: $0.value.token, name: $0.value.name,
                          seconds: Int($0.value.seconds), pickups: $0.value.pickups) }
            // An app opened over and over for seconds at a time belongs in the
            // list even though it barely registers as screen time.
            .filter { $0.seconds >= 60 || $0.pickups >= 3 }
            .sorted { $0.seconds > $1.seconds }

        return ActivityModel(totalSeconds: Int(total), pickups: pickups, apps: apps)
    }
}
