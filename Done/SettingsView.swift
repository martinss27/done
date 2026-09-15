import SwiftUI

struct SettingsView: View {
    @Bindable var blocks: BlockController
    @Bindable var health: Health
    @Bindable var geofence: Geofence
    @AppStorage("appearance") private var appearance = Appearance.dark
    @State private var feedback = Feedback()

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("App permissions") {
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
                    if geofence.isAuthorized {
                        Label("Location always allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button { geofence.requestAuthorization() } label: {
                            Label("Allow location always", systemImage: "mappin.and.ellipse")
                        }
                        Text("A place-based block only flips when iOS can see you cross the circle with Done closed, which needs Always.")
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
                }
                Section("Feedback") {
                    NavigationLink {
                        FeedbackView(feedback: feedback)
                    } label: {
                        LabeledContent {
                            if feedback.openCount > 0 { Text("\(feedback.openCount) open") }
                        } label: {
                            Label("Send feedback", systemImage: "bubble.left.and.text.bubble.right")
                        }
                    }
                    Text("Your feedback shapes what Done becomes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings")
        }
    }
}
