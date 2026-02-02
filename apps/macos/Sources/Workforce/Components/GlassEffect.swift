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
                    .fill(.ultraThinMaterial)
                    .opacity(self.isActive ? 0.85 : 0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: self.cornerRadius)
                    .stroke(
                        Color.white.opacity(self.isHovered ? 0.5 : 0.3),
                        lineWidth: self.isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: .black.opacity(self.isHovered ? 0.12 : 0.05),
                radius: self.isHovered ? 12 : 6,
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
