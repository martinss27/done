import SwiftUI

struct InsightsView: View {
    @Bindable var store: HabitStore

    private var doneToday: Int { store.habits.filter { $0.isDone(on: Date()) }.count }
    private var bestStreak: Int { store.habits.map(\.streak).max() ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        stat("\(doneToday)/\(store.habits.count)", "hoje")
                        stat("\(bestStreak)", "maior streak")
                    }
                    ForEach(store.habits) { habit in
                        HStack {
                            Text(habit.name)
                            Spacer()
                            Text("\(habit.streak)🔥").foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Insights")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.largeTitle.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}
