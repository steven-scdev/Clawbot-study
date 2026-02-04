import SwiftUI

/// Individual item in the dock-style artifact fan-out.
/// Glass capsule pill with output type icon and title.
struct ArtifactStackFanItemView: View {
    let output: TaskOutput
    let isVisible: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.onTap) {
            HStack(spacing: 8) {
                Image(systemName: self.output.type.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.blue.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(self.output.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.2))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(self.isHovered ? 0.75 : 0.6))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(self.isHovered ? 0.5 : 0.25), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(self.isHovered ? 0.18 : 0.1),
                radius: self.isHovered ? 10 : 5,
                y: self.isHovered ? 3 : 1
            )
            .scaleEffect(self.isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
        .opacity(self.isVisible ? 1 : 0)
        .scaleEffect(self.isVisible ? 1 : 0.3)
        .accessibilityLabel("Open \(self.output.title)")
    }
}
