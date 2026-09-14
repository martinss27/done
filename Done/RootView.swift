import SwiftUI

struct RootView: View {
    @Bindable var store: HabitStore
    @State private var blocks = BlockController()
    @State private var health = Health()
    @State private var geofence = Geofence()
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = Appearance.dark

    var body: some View {
        TabView {
            BlocksView(store: store, blocks: blocks)
                .tabItem { Label("Blocks", systemImage: "shield.fill") }
            PomodoroView(store: store, blocks: blocks)
                .tabItem { Label { Text("Focus") } icon: { tomatoSymbol } }
            InsightsView(blocks: blocks)
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            SettingsView(blocks: blocks, health: health, geofence: geofence)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(appearance.scheme)
        .tint(Color.primary)
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
        geofence.sync(store.habits)
    }
}

/// Dark is the default so the app looks the way it always has until you pick.
enum Appearance: String, CaseIterable {
    case system, light, dark

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
