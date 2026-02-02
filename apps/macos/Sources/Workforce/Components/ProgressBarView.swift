import SwiftUI

struct ProgressBarView: View {
    var progress: Double
    var height: CGFloat = 6
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: self.height / 2)
                    .fill(Color.secondary.opacity(0.2))

                RoundedRectangle(cornerRadius: self.height / 2)
                    .fill(self.tint)
                    .frame(width: geometry.size.width * min(max(self.progress, 0), 1))
                    .animation(.easeInOut(duration: 0.4), value: self.progress)
            }
        }
        .frame(height: self.height)
    }
}
