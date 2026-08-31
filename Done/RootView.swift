import SwiftUI

struct RootView: View {
    @Bindable var store: HabitStore
    @State private var blocks = BlockController()
    @State private var health = Health()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            BlocksView(store: store, blocks: blocks)
                .tabItem { Label("Blocks", systemImage: "shield.fill") }
            PomodoroView(store: store, blocks: blocks)
                .tabItem { Label { Text("Focus") } icon: { tomatoSymbol } }
            InsightsView(blocks: blocks)
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            SettingsView(blocks: blocks, health: health)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task { await refreshSteps() }
        .onChange(of: store.habits) { Task { await refreshSteps() } }
        .onChange(of: blocks.selections) { Task { await refreshSteps() } }
        .onChange(of: blocks.unlockSelections) { Task { await refreshSteps() } }
        .onChange(of: phase) { if phase == .active { Task { await refreshSteps() } } }
    }

    /// Health is the only unlock source that changes while the app is closed,
    /// so every return to the foreground re-reads it before re-shielding.
    private func refreshSteps() async {
        await health.refresh()
        blocks.steps = health.steps
        blocks.workoutMinutes = health.workoutMinutes
        blocks.mindfulMinutes = health.mindfulMinutes
        blocks.apply(store.habits)
    }
}
