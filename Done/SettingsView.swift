import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Bloqueio de apps") {
                    // ponytail: precisa de Apple Developer Program + FamilyControls.
                    Label("Em breve", systemImage: "lock.badge.clock")
                        .foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Versão", value: "0.1")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
