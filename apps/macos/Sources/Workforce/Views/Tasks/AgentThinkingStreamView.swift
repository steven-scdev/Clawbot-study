import SwiftUI

/// Shows the latest 2-3 internal agent activities (thinking, tool use) as
/// animated transient text lines below chat bubbles. Lines slide in from below
/// and fade out when a new `.text` response arrives.
struct AgentThinkingStreamView: View {
    let activities: [TaskActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(self.activities.suffix(3)) { activity in
                self.activityLine(activity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
        }
        .padding(.leading, 36)
        .animation(.easeInOut(duration: 0.3), value: self.activities.map(\.id))
    }

    private func activityLine(_ activity: TaskActivity) -> some View {
        let isPlanning = activity.type == .planning
        return HStack(spacing: 6) {
            Image(systemName: self.icon(for: activity.type))
                .font(.system(size: 10))
                .foregroundStyle(isPlanning ? Color.accentColor : Color(white: 0.5))

            Text(self.displayText(for: activity))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isPlanning ? Color.accentColor.opacity(0.8) : Color(white: 0.45))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(isPlanning ? Color.accentColor.opacity(0.08) : Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func icon(for type: ActivityType) -> String {
        switch type {
        case .thinking: "brain"
        case .toolCall: "wrench.and.screwdriver"
        case .toolResult: "checkmark.rectangle"
        case .planning: "sparkle.magnifyingglass"
        default: "circle"
        }
    }

    private func displayText(for activity: TaskActivity) -> String {
        switch activity.type {
        case .thinking:
            let text = activity.message.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Thinking..." : text
        case .toolCall:
            return activity.message
        case .toolResult:
            return activity.message
        default:
            return activity.message
        }
    }
}
