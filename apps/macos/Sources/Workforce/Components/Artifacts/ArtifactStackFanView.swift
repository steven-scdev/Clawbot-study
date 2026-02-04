import SwiftUI

/// Dock-style fan-out overlay that displays task outputs in a vertical stack
/// fanning upward from the anchor button, with staggered spring animations.
/// Does not manage its own dismiss backdrop — the parent handles that.
struct ArtifactStackFanView: View {
    let outputs: [TaskOutput]
    let anchorPoint: CGPoint
    let onSelect: (String) -> Void

    @State private var itemsVisible: [Bool] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let maxVisible = 8

    private var visibleOutputs: [TaskOutput] {
        if self.outputs.count <= self.maxVisible {
            return self.outputs
        }
        return Array(self.outputs.suffix(self.maxVisible - 1))
    }

    private var overflowCount: Int {
        max(0, self.outputs.count - self.maxVisible + 1)
    }

    var body: some View {
        ZStack {
            ForEach(Array(self.visibleOutputs.enumerated()), id: \.element.id) { index, output in
                let itemIndex = self.overflowCount > 0 ? index + 1 : index
                ArtifactStackFanItemView(
                    output: output,
                    isVisible: self.itemVisible(at: itemIndex),
                    onTap: { self.onSelect(output.id) }
                )
                .position(
                    x: self.anchorPoint.x + CGFloat(itemIndex) * 3,
                    y: self.anchorPoint.y - CGFloat(itemIndex + 1) * 52
                )
                .animation(
                    self.reduceMotion
                        ? .easeOut(duration: 0.15)
                        : .spring(response: 0.4, dampingFraction: 0.7).delay(Double(itemIndex) * 0.05),
                    value: self.itemVisible(at: itemIndex)
                )
            }

            if self.overflowCount > 0 {
                Text("+\(self.overflowCount) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.5))
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .opacity(self.itemVisible(at: 0) ? 1 : 0)
                    .position(
                        x: self.anchorPoint.x,
                        y: self.anchorPoint.y - CGFloat(self.visibleOutputs.count + 1) * 52
                    )
            }
        }
        .allowsHitTesting(true)
        .onAppear { self.show() }
    }

    private func itemVisible(at index: Int) -> Bool {
        guard index < self.itemsVisible.count else { return false }
        return self.itemsVisible[index]
    }

    private func show() {
        let count = self.visibleOutputs.count + (self.overflowCount > 0 ? 1 : 0)
        self.itemsVisible = Array(repeating: false, count: count)
        for i in 0..<count {
            let delay = self.reduceMotion ? 0 : Double(i) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < self.itemsVisible.count else { return }
                self.itemsVisible[i] = true
            }
        }
    }
}
