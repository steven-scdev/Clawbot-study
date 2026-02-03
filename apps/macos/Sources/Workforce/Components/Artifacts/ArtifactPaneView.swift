import SwiftUI

/// Right-pane container for artifact preview with header, renderer, and approve button
struct ArtifactPaneView: View {
    let output: TaskOutput?
    let allOutputs: [TaskOutput]
    let showApproveButton: Bool
    var taskService: TaskService
    let taskId: String
    let onOutputSelect: (String) -> Void
    let onClose: () -> Void
    let onApprove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with output selector and close button
            ArtifactHeaderView(
                currentOutput: output,
                allOutputs: allOutputs,
                onOutputSelect: onOutputSelect,
                onClose: onClose
            )

            Divider()

            // Artifact renderer or placeholder
            if let output {
                ArtifactRendererView(
                    output: output,
                    taskService: taskService,
                    taskId: taskId
                )
            } else {
                emptyStatePlaceholder
            }

            // Approve button (only shown when task is completed)
            if showApproveButton {
                Divider()
                approveButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStatePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No Output Available")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Waiting for the task to generate output...")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.97))
    }

    private var approveButton: some View {
        Button {
            onApprove()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("Looks Great")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.98))
    }
}
