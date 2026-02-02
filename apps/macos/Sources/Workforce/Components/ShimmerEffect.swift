import SwiftUI

// MARK: - Shimmer Overlay

struct ShimmerOverlay: View {
    var isActive: Bool

    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            if self.isActive {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.3), location: 0.5),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    startPoint: .init(x: self.phase, y: 0.3),
                    endPoint: .init(x: self.phase + 0.6, y: 0.7)
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear {
                    withAnimation(
                        .linear(duration: 3)
                            .repeatForever(autoreverses: false)
                    ) {
                        self.phase = 1.5
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                ShimmerOverlay(isActive: self.isActive)
                    .opacity(0.3)
            )
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}
