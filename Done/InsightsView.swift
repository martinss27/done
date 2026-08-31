import DeviceActivity
import SwiftUI

enum Period: String, CaseIterable {
    case today = "Today", week = "Week"

    var interval: DateInterval {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return DateInterval(start: cal.startOfDay(for: now), end: now)
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
            return DateInterval(start: start, end: now)
        }
    }
}

struct InsightsView: View {
    @Bindable var blocks: BlockController
    @State private var period: Period = .today
    @State private var hidden = false

    var body: some View {
        NavigationStack {
            Group {
                if blocks.isAuthorized {
                    DeviceActivityReport(.totalActivity, filter: filter)
                        .blur(radius: hidden ? 18 : 0)
                } else {
                    ContentUnavailableView("Screen Time is off",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Grant access in Settings to see your usage."))
                }
            }
            .navigationTitle("insights")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $period) {
                        ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { hidden.toggle() } label: {
                        Image(systemName: hidden ? "eye.slash" : "eye")
                    }
                }
            }
        }
    }

    private var filter: DeviceActivityFilter {
        DeviceActivityFilter(segment: .daily(during: period.interval),
                             users: .all,
                             devices: .init([.iPhone]))
    }
}
