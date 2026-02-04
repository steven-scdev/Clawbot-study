import SwiftUI

/// Glass status card showing the agent's working state with avatar, status label, activity message, and progress bar.
struct AgentWorkingCard: View {
    let employeeName: String
    var avatarSystemName: String = "person.circle.fill"
    var latestActivityMessage: String = ""
    var progress: Double = 0.0

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with glow border
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: self.avatarSystemName)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .glowBorder(isActive: true, cornerRadius: 10)

            // Status text + progress
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusDotView(color: .orange, size: 6, isPulsing: true)

                    Text("\(self.employeeName.uppercased()) IS WORKING")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }

                if !self.latestActivityMessage.isEmpty {
                    Text("\"\(self.latestActivityMessage)\"")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .italic()
                }

                ProgressBarView(progress: self.progress, height: 4, tint: .accentColor)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.2))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(
            color: Color(red: 0.12, green: 0.15, blue: 0.53).opacity(0.08),
            radius: 8, y: 3
        )
    }
}
