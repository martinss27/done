import SwiftUI

struct AddHabitView: View {
    @Bindable var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var minutes = 5

    var body: some View {
        NavigationStack {
            Form {
                TextField("Read a book", text: $name)
                Stepper("\(minutes) min per day", value: $minutes, in: 1...120)
            }
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.habits.append(Habit(name: name, targetMinutes: minutes))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
