import SwiftUI

// MARK: - Glow Border Modifier

struct GlowBorder: ViewModifier {
    var isActive: Bool
    var color: Color = .blue
    var cornerRadius: CGFloat = 20

    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if self.isActive {
                        RoundedRectangle(cornerRadius: self.cornerRadius)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        self.color.opacity(0.6),
                                        .purple.opacity(0.4),
                                        .cyan.opacity(0.6),
                                        self.color.opacity(0.6),
                                    ]),
                                    center: .center,
                                    angle: .degrees(self.rotation)
                                ),
                                lineWidth: 2
                            )
                            .blur(radius: 1)

                        // Outer glow
                        RoundedRectangle(cornerRadius: self.cornerRadius)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        self.color.opacity(0.3),
                                        .purple.opacity(0.2),
                                        .cyan.opacity(0.3),
                                        self.color.opacity(0.3),
                                    ]),
                                    center: .center,
                                    angle: .degrees(self.rotation)
                                ),
                                lineWidth: 4
                            )
                            .blur(radius: 6)
                    }
                }
            )
            .onAppear {
                if self.isActive {
                    withAnimation(
                        .linear(duration: 4)
                            .repeatForever(autoreverses: false)
                    ) {
                        self.rotation = 360
                    }
                }
            }
    }
}

extension View {
    func glowBorder(
        isActive: Bool,
        color: Color = .blue,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.modifier(GlowBorder(
            isActive: isActive,
            color: color,
            cornerRadius: cornerRadius
        ))
    }
}
