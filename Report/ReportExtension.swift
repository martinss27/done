import DeviceActivity
import SwiftUI

@main
struct DoneReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { model in ActivityView(model: model) }
    }
}
