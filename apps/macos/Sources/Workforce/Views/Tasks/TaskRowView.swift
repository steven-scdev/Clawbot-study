import SwiftUI

struct TaskRowView: View {
    let task: WorkforceTask
    let employee: Employee?

    var body: some View {
        HStack(spacing: 12) {
            Text(self.employee?.emoji ?? "?")
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.task.description)
                    .font(.callout)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(self.employee?.name ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(self.timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            self.trailingContent
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch self.task.status {
        case .running, .pending:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressBarView(progress: self.task.progress)
                    .frame(width: 80)
                Text("\(Int(self.task.progress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
    }

    private var timeLabel: String {
        if let completed = self.task.completedAt {
            return completed.formatted(date: .omitted, time: .shortened)
        }
        return self.task.createdAt.formatted(date: .omitted, time: .shortened)
    }
}
