import SwiftUI

struct RootView: View {
    @Bindable var store: HabitStore
    @State private var blocks = BlockController()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            BlocksView(store: store, blocks: blocks)
                .tabItem { Label("Blocks", systemImage: "shield.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            SettingsView(blocks: blocks)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task { blocks.apply(store.habits) }
        .onChange(of: store.habits) { blocks.apply(store.habits) }
        .onChange(of: blocks.selections) { blocks.apply(store.habits) }
        .onChange(of: phase) { if phase == .active { blocks.apply(store.habits) } }
    }
}
