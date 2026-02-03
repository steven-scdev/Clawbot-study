import SwiftUI

struct TaskRowView: View {
    let task: WorkforceTask
    let employee: Employee?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Avatar with status dot
            self.avatarView

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(self.task.description)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(white: 0.2))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Status indicator
                    StatusDotView(
                        color: self.statusColor,
                        size: 6,
                        isPulsing: self.task.status == .running || self.task.status == .pending
                    )

                    Text(self.statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(self.statusColor)

                    Text(self.employee?.name ?? "Unknown")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))

                    Text(self.relativeTimeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))
                }
            }

            Spacer()

            // Output pills + more button
            HStack(spacing: 6) {
                ForEach(self.task.outputs.prefix(2)) { output in
                    OutputPillView(output: output)
                }

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.5))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(self.isHovered ? 1 : 0.5)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24, isHovered: self.isHovered)
        .opacity(self.task.status == .cancelled ? 0.7 : 1)
        .scaleEffect(self.isHovered ? 1.005 : 1)
        .animation(.easeOut(duration: 0.2), value: self.isHovered)
        .onHover { hovering in
            self.isHovered = hovering
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Avatar

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: self.avatarGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Text(self.employee?.emoji ?? "?")
                        .font(.system(size: 22))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)

            // Status dot overlay
            Circle()
                .fill(self.statusDotColor)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .offset(x: 2, y: 2)
        }
    }

    // MARK: - Computed Properties

    private var statusLabel: String {
        switch self.task.status {
        case .completed: "Completed"
        case .running: "In Progress"
        case .pending: "Pending"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .unknown: "Unknown"
        }
    }

    private var statusColor: Color {
        switch self.task.status {
        case .completed: .green
        case .running, .pending: .blue
        case .failed: .red
        case .cancelled: .gray
        case .unknown: .gray
        }
    }

    private var statusDotColor: Color {
        switch self.task.status {
        case .completed: .green
        case .running, .pending: .blue
        case .failed: .red
        case .cancelled: Color(white: 0.6)
        case .unknown: Color(white: 0.6)
        }
    }

    private var avatarGradientColors: [Color] {
        switch self.task.status {
        case .completed: [.green.opacity(0.6), .mint.opacity(0.4)]
        case .running, .pending: [.blue.opacity(0.6), .purple.opacity(0.4)]
        case .failed: [.red.opacity(0.5), .orange.opacity(0.3)]
        case .cancelled: [.gray.opacity(0.4), .gray.opacity(0.3)]
        case .unknown: [.gray.opacity(0.4), .gray.opacity(0.3)]
        }
    }

    private var relativeTimeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let date = self.task.completedAt ?? self.task.createdAt
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Output Pill View

private struct OutputPillView: View {
    let output: TaskOutput

    var body: some View {
        Text(self.pillLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(self.pillTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(self.pillBackgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(self.pillBorderColor, lineWidth: 0.5)
            )
    }

    private var pillLabel: String {
        if !self.output.title.isEmpty {
            return self.output.title
        }
        switch self.output.type {
        case .file: return "File"
        case .document: return "Doc"
        case .website: return "Web"
        case .image: return "Image"
        case .unknown: return "Output"
        }
    }

    private var pillTextColor: Color {
        switch self.output.type {
        case .file: Color(red: 0.0, green: 0.35, blue: 0.8)
        case .document: Color(red: 0.45, green: 0.2, blue: 0.7)
        case .website: Color(red: 0.0, green: 0.5, blue: 0.5)
        case .image: Color(red: 0.7, green: 0.15, blue: 0.4)
        case .unknown: Color(white: 0.4)
        }
    }

    private var pillBackgroundColor: Color {
        switch self.output.type {
        case .file: .blue.opacity(0.1)
        case .document: .purple.opacity(0.1)
        case .website: .teal.opacity(0.1)
        case .image: .pink.opacity(0.1)
        case .unknown: .gray.opacity(0.1)
        }
    }

    private var pillBorderColor: Color {
        switch self.output.type {
        case .file: .blue.opacity(0.2)
        case .document: .purple.opacity(0.2)
        case .website: .teal.opacity(0.2)
        case .image: .pink.opacity(0.2)
        case .unknown: .gray.opacity(0.15)
        }
    }
}
