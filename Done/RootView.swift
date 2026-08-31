import SwiftUI

struct RootView: View {
    @Bindable var store: HabitStore

    var body: some View {
        TabView {
            BlocksView(store: store)
                .tabItem { Label("Blocks", systemImage: "shield.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
