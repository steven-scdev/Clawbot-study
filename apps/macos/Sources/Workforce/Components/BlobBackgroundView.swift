import SwiftUI

struct BlobBackgroundView: View {
    @Binding var blobPhase: CGFloat

    var body: some View {
        ZStack {
            // Full-screen base gradient (indigo → purple → rose)
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.89, blue: 0.97),
                    Color(red: 0.93, green: 0.88, blue: 0.95),
                    Color(red: 0.97, green: 0.90, blue: 0.93),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Large blue blob — upper-left area
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 550, height: 550)
                .blur(radius: 100)
                .offset(
                    x: -150 + self.blobPhase * 60,
                    y: -180 - self.blobPhase * 50
                )

            // Purple blob — upper-right area
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 450, height: 450)
                .blur(radius: 100)
                .offset(
                    x: 180 - self.blobPhase * 40,
                    y: -100 + self.blobPhase * 40
                )

            // Pink blob — bottom-center area
            Circle()
                .fill(Color.pink.opacity(0.13))
                .frame(width: 650, height: 650)
                .blur(radius: 100)
                .offset(
                    x: -30 - self.blobPhase * 20,
                    y: 250 - self.blobPhase * 60
                )
        }
        .allowsHitTesting(false)
    }
}
