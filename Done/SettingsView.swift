import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("App blocking") {
                    // ponytail: needs Apple Developer Program + FamilyControls.
                    Label("Coming soon", systemImage: "lock.badge.clock")
                        .foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Version", value: "0.1")
                }
            }
            .navigationTitle("settings")
        }
    }
}
