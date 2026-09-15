import SwiftUI

/// Settings → Report an issue: what was sent, with its status on GitHub.
struct FeedbackView: View {
    @Bindable var feedback: Feedback
    @State private var composing = false

    var body: some View {
        List {
            Section {
                Button { composing = true } label: {
                    Label("New report", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color(.systemBackground))
                .listRowBackground(Color.primary)
            }
            if !feedback.reports.isEmpty {
                Section {
                    ForEach(feedback.reports) { report in
                        Link(destination: report.url) { row(report) }
                    }
                    .onDelete(perform: feedback.remove)
                } header: {
                    Text("Your reports")
                } footer: {
                    Text("Status comes from GitHub. When an issue is closed, it shows as fixed here. Swipe left to remove one from this list.")
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .task { await feedback.refresh() }
        .refreshable { await feedback.refresh() }
        .sheet(isPresented: $composing) { NewReportView(feedback: feedback) }
    }

    private func row(_ report: Feedback.Report) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(report.title).foregroundStyle(.primary)
                Text("#\(report.number) · \(report.isIdea ? "Idea" : "Bug") · \(report.date.formatted(.relative(presentation: .named)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let color: Color = report.isOpen ? .green : .purple
            Text(report.isOpen ? "OPEN" : "FIXED")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .foregroundStyle(color)
                .background(color.opacity(0.15), in: .rect(cornerRadius: 10))
        }
    }
}

struct NewReportView: View {
    let feedback: Feedback
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isIdea = false
    @State private var sending = false
    @State private var failure: String?

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Kind", selection: $isIdea) {
                    Text("Bug").tag(false)
                    Text("Idea").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                Section {
                    TextEditor(text: $text).frame(minHeight: 220)
                } footer: {
                    Text("The first line becomes the issue title. Posted publicly to github.com/\(Feedback.repo). Leave out anything personal.")
                }
                if let failure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if sending {
                        ProgressView()
                    } else {
                        Button("Send") { Task { await send() } }.disabled(isEmpty)
                    }
                }
            }
            // A swipe down shouldn't throw away a half-written report.
            .interactiveDismissDisabled(!isEmpty)
        }
    }

    private func send() async {
        sending = true
        defer { sending = false }
        do {
            try await feedback.send(text, isIdea: isIdea)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
