import SwiftUI

struct SidebarUserProfile: View {
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Workspace")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Pro Plan")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "gear")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .opacity(self.isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(self.isHovered ? Color.white.opacity(0.1) : .clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}
