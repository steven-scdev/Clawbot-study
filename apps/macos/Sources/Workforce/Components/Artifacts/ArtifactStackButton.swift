import SwiftUI

/// Frosted glass folder button that triggers the artifact fan-out.
/// Displays a badge with the output count.
struct ArtifactStackButton: View {
    let outputCount: Int
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(self.isHovered ? 0.6 : 0.45))
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(self.isHovered ? 0.4 : 0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(self.isHovered ? 0.15 : 0.08),
                        radius: self.isHovered ? 10 : 5,
                        y: self.isHovered ? 3 : 1
                    )

                // Badge
                Text("\(self.outputCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
            .scaleEffect(self.isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovered = hovering
            }
        }
        .accessibilityLabel("Open artifact picker, \(self.outputCount) outputs available")
    }
}
