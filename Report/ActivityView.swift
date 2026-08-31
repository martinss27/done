import FamilyControls
import ManagedSettings
import SwiftUI

struct ActivityView: View {
    let model: ActivityModel

    private var peak: Int { model.apps.first?.seconds ?? 1 }

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
            }
        }
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
                        .foregroundStyle(app.seconds >= peak / 2 ? .orange : .green)
                        .monospacedDigit()
                }
                ProgressView(value: Double(app.seconds), total: Double(max(peak, 1)))
                    .tint(app.seconds >= peak / 2 ? .orange : .green)
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
