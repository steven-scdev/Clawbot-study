import SwiftUI

/// Header bar for the chat view matching the chatting-code.html design:
/// back chevron + "WORKFORCE / CHAT WITH {NAME}" breadcrumb on the left,
/// "ACTIVE SESSION" badge + task description + avatar on the right.
struct ChatHeaderView: View {
    let employee: Employee
    let taskDescription: String
    var taskStatus: TaskStatus = .running
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: self.onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("WORKFORCE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(white: 0.45))

            Text("/")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.6))

            Text("CHAT WITH \(self.employee.name.uppercased())")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color(white: 0.35))

            Spacer()

            // Session badge + task description
            VStack(alignment: .trailing, spacing: 2) {
                if self.taskStatus == .completed {
                    Text("COMPLETED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.green)
                } else {
                    Text("ACTIVE SESSION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.blue)
                }

                Text(self.taskDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}
