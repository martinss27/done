import SwiftUI

struct HabitListView: View {
    @Bindable var store: HabitStore
    @State private var newName = ""
    @State private var newMinutes = 5
    @State private var running: Habit?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.habits) { habit in
                        Button { running = habit } label: { row(habit) }
                            .disabled(habit.isDone(on: Date()))
                    }
                    .onDelete { store.habits.remove(atOffsets: $0) }
                }

                Section("Novo hábito") {
                    TextField("Ler", text: $newName)
                    Stepper("\(newMinutes) min por dia", value: $newMinutes, in: 1...120)
                    Button("Adicionar") {
                        store.habits.append(Habit(name: newName, targetMinutes: newMinutes))
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Done")
            .fullScreenCover(item: $running) { habit in
                SessionView(habit: habit) { store.complete(habit) }
            }
        }
    }

    private func row(_ habit: Habit) -> some View {
        HStack {
            Image(systemName: habit.isDone(on: Date()) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(habit.isDone(on: Date()) ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(habit.name)
                Text("\(habit.targetMinutes) min").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if habit.streak > 0 {
                Text("\(habit.streak)🔥").font(.caption.bold())
            }
        }
    }
}
