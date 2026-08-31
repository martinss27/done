import FamilyControls
import ManagedSettings
import SwiftUI

/// What the list is ranked by. Time answers "where did the day go"; pickups
/// answers "what keeps pulling me back", which is a different app more often
/// than not.
enum Rank: String, CaseIterable {
    case time, pickups
}

struct ActivityView: View {
    let model: ActivityModel
    @State private var rank: Rank = .time

    private var apps: [AppRow] {
        switch rank {
        case .time: model.apps.sorted { $0.seconds > $1.seconds }
        case .pickups: model.apps.sorted { $0.pickups > $1.pickups }
        }
    }

    private var peak: Int {
        switch rank {
        case .time: max(apps.first?.seconds ?? 1, 1)
        case .pickups: max(apps.first?.pickups ?? 1, 1)
        }
    }

    /// Absolute thresholds, so a colour means the same thing every day —
    /// relative-to-peak shading made a quiet day look as bad as a heavy one.
    private static let bands: [(minutes: Int, color: Color, label: String)] = [
        (0, .green, "light"),
        (30, .yellow, "30m+"),
        (45, .orange, "45m+"),
        (90, .red, "90m+"),
    ]

    /// Pickup bands are about frequency, not duration, so they get their own
    /// thresholds rather than borrowing the minute ones.
    private static let pickupBands: [(count: Int, color: Color, label: String)] = [
        (0, .green, "few"),
        (10, .yellow, "10+"),
        (25, .orange, "25+"),
        (50, .red, "50+"),
    ]

    private func band(_ app: AppRow) -> Color {
        switch rank {
        case .time: Self.bands.last { app.seconds / 60 >= $0.minutes }?.color ?? .green
        case .pickups: Self.pickupBands.last { app.pickups >= $0.count }?.color ?? .green
        }
    }

    var body: some View {
        // The report owns its scrolling: it lives in another process, so a
        // ScrollView on the app side would fight this one.
        ScrollView {
            content.padding(16)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            summary
            if model.apps.isEmpty {
                Text("no activity yet today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 40)
            } else {
                Picker("", selection: $rank) {
                    ForEach(Rank.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 18) {
                    ForEach(apps) { row($0) }
                }
                .padding(16)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                legend
            }
        }
    }

    private var legend: some View {
        let labels: [(color: Color, label: String)] = rank == .time
            ? Self.bands.map { ($0.color, $0.label) }
            : Self.pickupBands.map { ($0.color, $0.label) }
        return HStack {
            ForEach(labels, id: \.label) { band in
                HStack(spacing: 6) {
                    Circle().fill(band.color).frame(width: 8, height: 8)
                    Text(band.label)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text(model.totalSeconds.duration)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            HStack(spacing: 24) {
                Label("screen time", systemImage: "hourglass")
                Label("\(model.pickups) pickups", systemImage: "iphone")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private func row(_ app: AppRow) -> some View {
        HStack(spacing: 12) {
            Group {
                if let token = app.token {
                    // Only the system may draw a real app icon and name.
                    Label(token).labelStyle(.iconOnly)
                } else {
                    Image(systemName: "app.dashed")
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(app.name).font(.title3).lineLimit(1)
                    Spacer()
                    Text(rank == .time ? app.seconds.duration : "\(app.pickups)×")
                        .foregroundStyle(band(app))
                        .monospacedDigit()
                }
                ProgressView(value: Double(rank == .time ? app.seconds : app.pickups),
                             total: Double(peak))
                    .tint(band(app))
                if rank == .pickups {
                    Text("\(app.pickups) pickups · \(app.seconds.duration) · \(app.secondsPerPickup.duration) each")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

}
