import SwiftUI

struct SettingsView: View {
    @Bindable var blocks: BlockController
    @Bindable var health: Health

    var body: some View {
        NavigationStack {
            List {
                Section("App blocking") {
                    if blocks.isAuthorized {
                        Label("Screen Time access granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await blocks.requestAuthorization() }
                        } label: {
                            Label("Grant Screen Time access", systemImage: "lock.open")
                        }
                        Text("Needed to lock apps until a habit is done.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Health") {
                    LabeledContent("Steps today", value: "\(health.steps)")
                    LabeledContent("Workout today", value: "\(health.workoutMinutes) min")
                    LabeledContent("Meditation today", value: "\(health.mindfulMinutes) min")
                    Button {
                        Task { await health.requestAccess() }
                    } label: {
                        Label("Connect Apple Health", systemImage: "heart.fill")
                    }
                    Text("Garmin syncs into Apple Health on its own schedule, so steps refresh when you open Done.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Blocking debug") {
                    LabeledContent("Monitored", value: "\(Monitoring.active.count)")
                    LabeledContent("Banked", value: "\(blocks.gate.banked.count)")
                    LabeledContent("Open", value: "\(blocks.gate.open.count)")
                    ForEach(Diagnostics.lines, id: \.self) { line in
                        Text(line).font(.caption2.monospaced())
                    }
                    Button("Clear log") { Diagnostics.clear() }
                }
                Section {
                    LabeledContent("Version", value: "0.2")
                }
            }
            .navigationTitle("settings")
        }
    }
}
