import SwiftUI

struct StageIndicatorView: View {
    let currentStage: TaskStage

    private static let stages: [TaskStage] = [.clarify, .plan, .execute, .review, .deliver]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.stages.enumerated()), id: \.element) { index, stage in
                self.stageItem(stage)
                if index < Self.stages.count - 1 {
                    self.connector(active: self.isReached(stage))
                }
            }
        }
    }

    private func stageItem(_ stage: TaskStage) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(self.isReached(stage) ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: stage.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.isReached(stage) ? .white : .secondary)
            }
            Text(stage.label)
                .font(.system(size: 10))
                .foregroundStyle(self.isCurrent(stage) ? .primary : .secondary)
                .fontWeight(self.isCurrent(stage) ? .semibold : .regular)
        }
    }

    private func connector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.accentColor : Color.secondary.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16) // align with circle center
    }

    private func isReached(_ stage: TaskStage) -> Bool {
        guard let currentIndex = Self.stages.firstIndex(of: self.currentStage),
              let stageIndex = Self.stages.firstIndex(of: stage)
        else { return false }
        return stageIndex <= currentIndex
    }

    private func isCurrent(_ stage: TaskStage) -> Bool {
        stage == self.currentStage
    }
}
