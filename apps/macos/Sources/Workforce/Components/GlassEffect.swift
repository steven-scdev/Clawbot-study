import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var isHovered: Bool = false
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: self.cornerRadius)
                    .fill(self.isActive
                        ? Color.white.opacity(0.65)
                        : Color.white.opacity(self.isHovered ? 0.45 : 0.35))
            )
            .background(
                RoundedRectangle(cornerRadius: self.cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: self.cornerRadius)
                    .stroke(
                        Color.white.opacity(self.isHovered ? 0.6 : 0.4),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color(red: 0.12, green: 0.15, blue: 0.53).opacity(self.isHovered ? 0.15 : 0.08),
                radius: self.isHovered ? 16 : 8,
                y: self.isHovered ? 6 : 3
            )
            .clipShape(RoundedRectangle(cornerRadius: self.cornerRadius))
    }
}

// MARK: - Glass Surface (for sidebar, header, status bar)

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: self.cornerRadius))
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        isHovered: Bool = false,
        isActive: Bool = false
    ) -> some View {
        self.modifier(GlassCard(
            cornerRadius: cornerRadius,
            isHovered: isHovered,
            isActive: isActive
        ))
    }

    func glassSurface(cornerRadius: CGFloat = 0) -> some View {
        self.modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}
