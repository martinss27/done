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
        // No navigation bar: the report is a remote view that scrolls itself,
        // and a large title would slide under it and clip.
        VStack(spacing: 12) {
            header
            if blocks.isAuthorized {
                DeviceActivityReport(.totalActivity, filter: filter)
                    .blur(radius: hidden ? 18 : 0)
            } else {
                Spacer()
                ContentUnavailableView("Screen Time is off",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Grant access in Settings to see your usage."))
                Spacer()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("insights").font(.largeTitle.weight(.bold))
            Spacer(minLength: 8)
            Picker("", selection: $period) {
                ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            Button { hidden.toggle() } label: {
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filter: DeviceActivityFilter {
        DeviceActivityFilter(segment: .daily(during: period.interval),
                             users: .all,
                             devices: .init([.iPhone]))
    }
}
