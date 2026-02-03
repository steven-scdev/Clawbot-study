import SwiftUI

struct TaskProgressView: View {
    let task: WorkforceTask
    let employee: Employee?
    var taskService: TaskService
    var onDismiss: () -> Void
    var onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            Divider()
            self.stageAndProgress
            Divider()
            ActivityLogView(activities: self.task.activities)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            self.controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(self.task.description)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let employee {
                Text(employee.emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(self.statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "person.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Employee")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(self.statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusDotView(
                color: self.statusColor,
                isPulsing: self.task.status == .running)
        }
        .padding(20)
    }

    private var stageAndProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageIndicatorView(currentStage: self.task.stage)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(self.task.description)
                        .font(.callout)
                        .lineLimit(2)
                    Spacer()
                    Text("\(Int(self.task.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressBarView(progress: self.task.progress)
            }
        }
        .padding(20)
    }

    private var controls: some View {
        HStack {
            Button("Back") {
                self.onDismiss()
            }

            Spacer()

            if self.task.status == .completed {
                Button("Review Output") {
                    self.onReview()
                }
                .buttonStyle(.borderedProminent)
            }

            TaskControlsView(status: self.task.status) {
                Task { await self.taskService.cancelTask(id: self.task.id) }
            }
        }
        .padding(20)
    }

    private var statusLabel: String {
        switch self.task.status {
        case .running: "Working on your task..."
        case .pending: "Waiting to start..."
        case .completed: "Task complete"
        case .failed: self.task.errorMessage ?? "Task failed"
        case .cancelled: "Task cancelled"
        case .unknown: "Status unknown"
        }
    }

    private var statusColor: Color {
        switch self.task.status {
        case .running: .green
        case .pending: .yellow
        case .completed: .blue
        case .failed: .red
        case .cancelled: .secondary
        case .unknown: .secondary
        }
    }
}
