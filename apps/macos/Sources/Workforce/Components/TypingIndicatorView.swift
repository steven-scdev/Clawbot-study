import SwiftUI

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .fill(Color(white: 0.55))
                    .frame(width: 6, height: 6)
                    .scaleEffect(self.animating ? 1.0 : 0.5)
                    .opacity(self.animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: self.animating
                    )
            }
        }
        .onAppear { self.animating = true }
    }
}
