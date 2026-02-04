//
//  NeedsAttentionSection.swift
//  Workforce
//
//  Dashboard section showing tasks that need user attention (clarification, plan approval, or output review).
//

import SwiftUI

struct NeedsAttentionSection: View {
    let items: [NeedsAttentionItem]
    let onTap: (NeedsAttentionItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("NEEDS ATTENTION")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.5))
                    .tracking(1.5)

                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.8))
                        )
                }

                Spacer()
            }

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
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green.opacity(0.8))

            Text("All clear — no one needs you")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(white: 0.6))

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.25))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Cards Grid

    private var cardsView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(items) { item in
                AttentionCardView(item: item, onTap: onTap)
            }
        }
    }
}

// MARK: - Attention Card View

private struct AttentionCardView: View {
    let item: NeedsAttentionItem
    let onTap: (NeedsAttentionItem) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap(item)
        } label: {
            HStack(spacing: 16) {
                // Employee emoji avatar
                Text(item.employee.emoji)
                    .font(.system(size: 32))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    // Employee name + action type
                    HStack(spacing: 6) {
                        Text(item.employee.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.2))

                        Image(systemName: actionTypeIcon(item.actionType))
                            .font(.system(size: 12))
                            .foregroundColor(actionTypeColor(item.actionType))
                    }

                    // Context message
                    Text(item.message)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Timestamp
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(white: 0.4))
                }

                Spacer()

                // Action button
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(actionTypeColor(item.actionType))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(isHovered ? 0.45 : 0.35))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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

    private func actionTypeIcon(_ type: ActionType) -> String {
        switch type {
        case .clarification:
            return "questionmark.circle"
        case .planApproval:
            return "checkmark.circle"
        case .outputReview:
            return "eye"
        }
    }

    private func actionTypeColor(_ type: ActionType) -> Color {
        switch type {
        case .clarification:
            return .blue
        case .planApproval:
            return .blue
        case .outputReview:
            return .green
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes) min ago"
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
        name: "Emma",
        title: "Designer",
        emoji: "👩‍🎨",
        description: "UI/UX Designer",
        status: .online,
        capabilities: ["Design", "Prototyping"]
    )

    let employee2 = Employee(
        id: "2",
        name: "David",
        title: "Developer",
        emoji: "👨‍💻",
        description: "Full Stack Developer",
        status: .online,
        capabilities: ["Frontend", "Backend"]
    )

    let items: [NeedsAttentionItem] = [
        NeedsAttentionItem(
            id: "1",
            taskState: .reviewing(taskId: "1"),
            employee: employee1,
            actionType: .clarification,
            message: "How should the user profile page handle missing data?",
            timestamp: Date().addingTimeInterval(-1800) // 30 min ago
        ),
        NeedsAttentionItem(
            id: "2",
            taskState: .reviewing(taskId: "2"),
            employee: employee2,
            actionType: .planApproval,
            message: "Plan ready for approval",
            timestamp: Date().addingTimeInterval(-3600) // 1 hour ago
        ),
    ]

    return ZStack {
        Color.blue.opacity(0.1).ignoresSafeArea()
        NeedsAttentionSection(items: items) { item in
            print("Tapped item: \(item.id)")
        }
        .padding(32)
    }
    .frame(width: 1200, height: 300)
}
