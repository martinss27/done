import SwiftUI

struct SettingsView: View {
    @Bindable var blocks: BlockController
    @Bindable var health: Health
    @Bindable var geofence: Geofence

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
                Section("Location") {
                    if geofence.isAuthorized {
                        Label("Always allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button { geofence.requestAuthorization() } label: {
                            Label("Allow location always", systemImage: "mappin.and.ellipse")
                        }
                        Text("A place-based block only flips when iOS can see you cross the circle with Done closed, which needs Always.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings")
        }
    }
}
