import SwiftUI

@main
struct DoneApp: App {
    @State private var store = HabitStore()

    init() {
        FocusAlarm.install()
        #if DEBUG
        Habit.selfCheck()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
