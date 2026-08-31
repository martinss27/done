import SwiftUI

struct SettingsView: View {
    @Bindable var blocks: BlockController

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
                Section {
                    LabeledContent("Version", value: "0.2")
                }
            }
            .navigationTitle("settings")
        }
    }
}
