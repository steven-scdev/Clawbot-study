import SwiftUI

struct OutputReviewView: View {
    let task: WorkforceTask
    let employee: Employee?
    var taskService: TaskService
    var onDone: () -> Void
    var onRevise: () -> Void

    @State private var showRevisionInput = false
    @State private var revisionFeedback = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            Divider()
            self.outputList
            Divider()
            self.controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let employee {
                Text(employee.emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Task complete — review the results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)
        }
        .padding(20)
    }

    // MARK: - Output List

    private var outputList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(self.task.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !self.task.outputs.isEmpty {
                    ForEach(self.task.outputs) { output in
                        self.outputRow(output)
                    }
                }

                if !self.task.activities.isEmpty {
                    ActivityLogView(activities: self.task.activities)
                        .frame(maxHeight: 300)
                } else if self.task.outputs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No outputs recorded")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }

                if self.showRevisionInput {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Revision Notes")
                            .font(.headline)
                        TextEditor(text: self.$revisionFeedback)
                            .font(.body)
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func outputRow(_ output: TaskOutput) -> some View {
        HStack(spacing: 12) {
            Image(systemName: output.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(output.title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(output.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if output.filePath != nil {
                Button {
                    Task { await self.taskService.revealOutput(taskId: self.task.id, outputId: output.id) }
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Show in Finder")
            }

            Button {
                Task { await self.taskService.openOutput(taskId: self.task.id, outputId: output.id) }
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            Button("Back to Tasks") {
                self.onDone()
            }
            .buttonStyle(.bordered)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if self.showRevisionInput {
                Button("Submit Revision") {
                    Task { await self.submitRevision() }
                }
                .buttonStyle(.bordered)
                .disabled(self.revisionFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || self.isSubmitting)
            } else {
                Button("Request Changes") {
                    withAnimation { self.showRevisionInput = true }
                }
                .buttonStyle(.bordered)
            }

            Button("Looks Great") {
                self.onDone()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    // MARK: - Actions

    private func submitRevision() async {
        self.isSubmitting = true
        self.errorMessage = nil
        do {
            _ = try await self.taskService.requestRevision(
                taskId: self.task.id,
                feedback: self.revisionFeedback.trimmingCharacters(in: .whitespacesAndNewlines))
            self.onRevise()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }
}

// MARK: - OutputType Icon Extension

extension OutputType {
    var icon: String {
        switch self {
        case .file: "doc.fill"
        case .website: "globe"
        case .document: "doc.text.fill"
        case .image: "photo.fill"
        case .presentation: "rectangle.on.rectangle.angled"
        case .spreadsheet: "tablecells"
        case .video: "play.rectangle.fill"
        case .audio: "waveform"
        case .code: "curlybraces"
        case .unknown: "questionmark.square"
        }
    }
}
