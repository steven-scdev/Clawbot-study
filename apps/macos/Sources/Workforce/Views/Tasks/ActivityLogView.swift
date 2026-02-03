import SwiftUI

struct ActivityLogView: View {
    let activities: [TaskActivity]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(self.activities) { activity in
                        ActivityRowView(activity: activity)
                            .id(activity.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: self.activities.count) {
                if let last = self.activities.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct ActivityRowView: View {
    let activity: TaskActivity

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: self.activity.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(self.iconColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.activity.message)
                    .font(.system(.callout, design: .default))
                    .foregroundStyle(self.activity.type == .error ? .red : .primary)

                if let detail = self.activity.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer()

            Text(self.activity.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch self.activity.type {
        case .error: .red
        case .completion: .green
        case .toolCall: .orange
        case .toolResult: .blue
        case .thinking: .purple
        case .text: .primary
        case .userMessage: .blue
        case .unknown: .secondary
        }
    }
}
