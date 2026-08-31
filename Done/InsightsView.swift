import SwiftUI

/// ponytail: dados de exemplo. Trocar por um DeviceActivityReport quando o
/// entitlement `com.apple.developer.family-controls` existir — o layout já
/// é o mesmo que a extensão vai preencher.
struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Int
    let tint: Color
}

enum Period: String, CaseIterable {
    case today = "Today", week = "Week"
}

struct InsightsView: View {
    @State private var period: Period = .today
    @State private var hidden = false

    private var usage: [AppUsage] { Self.sample(period) }
    private var total: Int { usage.reduce(0) { $0 + $1.minutes } }
    private var pickups: Int { period == .today ? 35 : 214 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    appList
                    Text("dados de exemplo — screen time real exige o entitlement da Apple")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
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

    private var summary: some View {
        VStack(spacing: 8) {
            Text(format(total))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText())
            HStack(spacing: 24) {
                Label("screen time", systemImage: "hourglass")
                Label("\(pickups) pickups", systemImage: "iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .redacted(reason: hidden ? .placeholder : [])
    }

    private var appList: some View {
        VStack(spacing: 18) {
            ForEach(usage) { app in
                row(app, peak: usage.first?.minutes ?? 1)
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .redacted(reason: hidden ? .placeholder : [])
    }

    private func row(_ app: AppUsage, peak: Int) -> some View {
        HStack(spacing: 12) {
            Text(app.name.prefix(1))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(app.tint, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(app.name).font(.title3)
                    Spacer()
                    Text(format(app.minutes)).foregroundStyle(.green)
                }
                ProgressView(value: Double(app.minutes), total: Double(peak))
                    .tint(.green)
            }
        }
    }

    private func format(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private static func sample(_ period: Period) -> [AppUsage] {
        let base: [(String, Int, Color)] = [
            ("WhatsApp", 10, .green), ("YouTube", 9, .red), ("X", 9, .black),
            ("Done", 4, .gray), ("Books", 3, .orange), ("Spotify", 3, .green),
            ("Safari", 2, .blue), ("GymRats", 1, .red), ("Claude", 1, .brown),
        ]
        let factor = period == .today ? 1 : 6
        return base.map { AppUsage(name: $0.0, minutes: $0.1 * factor, tint: $0.2) }
    }
}
