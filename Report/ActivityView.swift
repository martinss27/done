import FamilyControls
import ManagedSettings
import SwiftUI

struct ActivityView: View {
    let model: ActivityModel

    private var peak: Int { model.apps.first?.seconds ?? 1 }

    /// Absolute thresholds, so a colour means the same thing every day —
    /// relative-to-peak shading made a quiet day look as bad as a heavy one.
    private static let bands: [(minutes: Int, color: Color, label: String)] = [
        (0, .green, "light"),
        (30, .yellow, "30m+"),
        (45, .orange, "45m+"),
        (90, .red, "90m+"),
    ]

    private func band(_ seconds: Int) -> Color {
        Self.bands.last { seconds / 60 >= $0.minutes }?.color ?? .green
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
                VStack(spacing: 18) {
                    ForEach(model.apps) { row($0) }
                }
                .padding(16)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                legend
            }
        }
    }

    private var legend: some View {
        HStack {
            ForEach(Self.bands, id: \.label) { band in
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
        VStack(spacing: 8) {
            Text(long(model.totalSeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            HStack(spacing: 24) {
                Label("screen time", systemImage: "hourglass")
                Label("\(model.pickups) pickups", systemImage: "iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
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
                    Text(short(app.seconds))
                        .foregroundStyle(band(app.seconds))
                        .monospacedDigit()
                }
                ProgressView(value: Double(app.seconds), total: Double(max(peak, 1)))
                    .tint(band(app.seconds))
            }
        }
    }

    private func short(_ seconds: Int) -> String {
        let m = seconds / 60
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }

    private func long(_ seconds: Int) -> String {
        let m = seconds / 60
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }
}
