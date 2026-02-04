//
//  InProgressSection.swift
//  Workforce
//
//  Dashboard section showing actively executing tasks with stage progress indicators.
//

import SwiftUI

struct InProgressSection: View {
    let items: [InProgressItem]
    let onTap: (InProgressItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("IN PROGRESS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(white: 0.5))
                .tracking(1.5)

            // Content
            if items.isEmpty {
                emptyStateView
            } else {
                cardsView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(Color(white: 0.4))

            Text("No active tasks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.3))

            Text("Assign work to get your team started")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.25))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Cards Stack

    private var cardsView: some View {
        VStack(spacing: 16) {
            ForEach(items) { item in
                ProgressCardView(item: item, onTap: onTap)
            }
        }
    }
}

// MARK: - Progress Card View

private struct ProgressCardView: View {
    let item: InProgressItem
    let onTap: (InProgressItem) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap(item)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Employee info
                HStack(spacing: 12) {
                    Text(item.employee.emoji)
                        .font(.system(size: 24))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.employee.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.2))

                        Text(relativeTimeString(from: item.elapsedTime))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.4))
                    }

                    Spacer()
                }

                // Task description
                Text(item.taskDescription)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Stage progress indicator
                StageIndicatorView(currentStage: item.currentStage)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(isHovered ? 0.45 : 0.35))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(isHovered ? 0.6 : 0.4), lineWidth: 1)
            )
            .shadow(
                color: Color(red: 0.12, green: 0.15, blue: 0.53).opacity(isHovered ? 0.12 : 0.08),
                radius: isHovered ? 12 : 8,
                y: 3
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Helpers

    private func relativeTimeString(from elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed / 60)
        let hours = Int(elapsed / 3600)
        let days = Int(elapsed / 86400)

        if minutes < 1 {
            return "just started"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days == 1 {
            return "yesterday"
        } else {
            return "\(days) days ago"
        }
    }
}

// MARK: - Preview

#Preview {
    let employee1 = Employee(
        id: "1",
        name: "Alex",
        title: "Designer",
        emoji: "👨‍🎨",
        description: "Senior Designer",
        status: .busy,
        capabilities: ["Design", "Prototyping"]
    )

    let employee2 = Employee(
        id: "2",
        name: "Sarah",
        title: "Developer",
        emoji: "👩‍💻",
        description: "Backend Developer",
        status: .busy,
        capabilities: ["Backend", "Database"]
    )

    let items: [InProgressItem] = [
        InProgressItem(
            id: "1",
            employee: employee1,
            taskDescription: "Design a modern dashboard for the workforce management system",
            currentStage: .execute,
            elapsedTime: 3600 // 1 hour
        ),
        InProgressItem(
            id: "2",
            employee: employee2,
            taskDescription: "Implement API endpoints for task management",
            currentStage: .plan,
            elapsedTime: 1800 // 30 minutes
        ),
    ]

    return ZStack {
        Color.blue.opacity(0.1).ignoresSafeArea()
        InProgressSection(items: items) { item in
            print("Tapped item: \(item.id)")
        }
        .padding(32)
    }
    .frame(width: 500, height: 500)
}
