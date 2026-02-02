import SwiftUI

struct StatusDotView: View {
    let color: Color
    var size: CGFloat = 8
    var isPulsing: Bool = false

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer pulse ring
            if self.isPulsing {
                Circle()
                    .fill(self.color.opacity(0.3))
                    .frame(width: self.size, height: self.size)
                    .scaleEffect(self.pulseScale)
                    .opacity(2.0 - Double(self.pulseScale))
            }

            // Core dot
            Circle()
                .fill(self.color)
                .frame(width: self.size, height: self.size)
        }
        .onAppear {
            if self.isPulsing {
                withAnimation(
                    .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    self.pulseScale = 2.0
                }
            }
        }
        .onChange(of: self.isPulsing) { _, newValue in
            if newValue {
                withAnimation(
                    .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    self.pulseScale = 2.0
                }
            } else {
                self.pulseScale = 1.0
            }
        }
    }
}
