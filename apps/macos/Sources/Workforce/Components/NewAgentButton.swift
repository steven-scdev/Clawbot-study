import SwiftUI

struct NewAgentButton: View {
    var action: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("New Agent")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color(white: 0.25))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.45))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(self.isHovered ? 0.4 : 0.2), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(self.isHovered ? 0.15 : 0.08),
                radius: self.isHovered ? 12 : 6,
                y: self.isHovered ? 4 : 2
            )
            .scaleEffect(self.isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovered = hovering
            }
        }
    }
}
