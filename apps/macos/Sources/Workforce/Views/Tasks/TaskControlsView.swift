import SwiftUI

struct TaskControlsView: View {
    let status: TaskStatus
    var onCancel: () -> Void

    var body: some View {
        HStack {
            Spacer()
            switch self.status {
            case .running, .pending:
                Button("Cancel Task", role: .destructive) {
                    self.onCancel()
                }
                .buttonStyle(.bordered)
            case .completed:
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            case .failed:
                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            case .cancelled:
                Label("Cancelled", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            case .unknown:
                EmptyView()
            }
        }
    }
}
