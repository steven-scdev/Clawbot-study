import SwiftUI

struct TaskInputView: View {
    let employee: Employee
    var taskService: TaskService
    var onTaskSubmitted: (WorkforceTask) -> Void
    var onCancel: () -> Void

    @State private var taskDescription = ""
    @State private var attachments: [URL] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.employeeHeader
            Divider()
            self.inputArea
            Divider()
            self.actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Assign Task to \(self.employee.name)")
    }

    private var employeeHeader: some View {
        HStack(spacing: 12) {
            Text(self.employee.emoji)
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(self.employee.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(self.employee.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Ready to help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like \(self.employee.name) to work on?")
                .font(.headline)

            TextEditor(text: self.$taskDescription)
                .font(.body)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if self.taskDescription.isEmpty {
                        Text("Describe the task…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

            if !self.attachments.isEmpty {
                self.attachmentsList
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
    }

    private var attachmentsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Attachments")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(self.attachments, id: \.absoluteString) { url in
                HStack {
                    Image(systemName: "doc")
                    Text(url.lastPathComponent)
                        .font(.caption)
                    Spacer()
                    Button {
                        self.attachments.removeAll { $0 == url }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Add File…") {
                self.pickFiles()
            }
            Spacer()
            Button("Cancel") {
                self.onCancel()
            }
            Button("Assign Task") {
                Task { await self.submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isSubmitting)
        }
        .padding(20)
    }

    private func submit() async {
        self.isSubmitting = true
        self.errorMessage = nil
        do {
            let task = try await self.taskService.submitTask(
                employeeId: self.employee.id,
                description: self.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            self.onTaskSubmitted(task)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            self.attachments.append(contentsOf: panel.urls)
        }
    }
}
