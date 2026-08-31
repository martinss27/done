import SwiftUI

struct AddHabitView: View {
    @Bindable var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var minutes = 5

    var body: some View {
        NavigationStack {
            Form {
                TextField("Ler um livro", text: $name)
                Stepper("\(minutes) min por dia", value: $minutes, in: 1...120)
            }
            .navigationTitle("Novo hábito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
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
