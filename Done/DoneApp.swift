import SwiftUI

@main
struct DoneApp: App {
    @State private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            HabitListView(store: store)
        }
    }
}
