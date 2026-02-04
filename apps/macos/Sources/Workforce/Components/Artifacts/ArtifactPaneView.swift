import SwiftUI

/// Frosted-glass artifact preview pane with browser chrome, inner content card,
/// agent working status, and approve button.
struct ArtifactPaneView: View {
    let output: TaskOutput?
    let allOutputs: [TaskOutput]
    let showApproveButton: Bool
    let isTaskRunning: Bool
    var taskService: TaskService
    let taskId: String
    let onOutputSelect: (String) -> Void
    let onClose: () -> Void
    let onApprove: () -> Void

    // Layout state (from parent)
    var isExpanded: Bool = false
    var isApproved: Bool = false
    var onExpand: () -> Void = {}

    // Agent status
    var employeeName: String = ""
    var avatarSystemName: String = "person.circle.fill"
    var latestActivityMessage: String = ""
    var taskProgress: Double = 0.0

    var body: some View {
        VStack(spacing: 0) {
            // Glass browser chrome
            ArtifactHeaderView(
                currentOutput: self.output,
                allOutputs: self.allOutputs,
                isExpanded: self.isExpanded,
                onOutputSelect: self.onOutputSelect,
                onClose: self.onClose,
                onExpand: self.onExpand
            )

            // Inner content card
            Group {
                if let output = self.output {
                    ArtifactRendererView(
                        output: output,
                        isTaskRunning: self.isTaskRunning,
                        taskService: self.taskService,
                        taskId: self.taskId
                    )
                } else {
                    emptyStatePlaceholder
                }
            }
            .innerContentCard(cornerRadius: 16)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, self.isTaskRunning || self.showApproveButton || self.isApproved ? 4 : 12)

            // Agent working card (visible only while running)
            if self.isTaskRunning {
                AgentWorkingCard(
                    employeeName: self.employeeName,
                    avatarSystemName: self.avatarSystemName,
                    latestActivityMessage: self.latestActivityMessage,
                    progress: self.taskProgress
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Approve button (visible when completed or already approved)
            if self.showApproveButton || self.isApproved {
                approveButton
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: 20)
        .padding(8)
    }

    // MARK: - Subviews

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
    }

    @ViewBuilder
    private var approveButton: some View {
        if self.isApproved {
            // Completed state — muted, non-interactive
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("Approved")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.6))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .transition(.scale.combined(with: .opacity))
        } else {
            // Active approve button
            Button(action: self.onApprove) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Looks Great")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}
