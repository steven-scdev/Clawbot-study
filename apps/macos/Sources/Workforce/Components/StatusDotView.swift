import SwiftUI

struct StatusDotView: View {
    let color: Color
    var size: CGFloat = 8
    var isPulsing: Bool = false

    var body: some View {
        Circle()
            .fill(self.color)
            .frame(width: self.size, height: self.size)
            .opacity(self.isPulsing ? 0.6 : 1.0)
            .animation(
                self.isPulsing
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: self.isPulsing)
    }
}
