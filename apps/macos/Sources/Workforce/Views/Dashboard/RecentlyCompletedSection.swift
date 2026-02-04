//
//  RecentlyCompletedSection.swift
//  Workforce
//
//  Dashboard section showing recently completed tasks that haven't been seen yet.
//

import SwiftUI

struct RecentlyCompletedSection: View {
    let items: [CompletedItem]
    let hasMore: Bool
    let onTap: (CompletedItem) -> Void
    let onMarkAllSeen: () -> Void
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("RECENTLY COMPLETED")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.5))
                    .tracking(1.5)

                Spacer()

                if !items.isEmpty {
                    Button {
                        onMarkAllSeen()
                    } label: {
                        Text("Mark all as seen")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        // Change cursor to pointer on hover
                    }
                }
            }

            // Content
            if items.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 16) {
                    cardsView

                    // View all button
                    if hasMore {
                        viewAllButton
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.green.opacity(0.6))

            Text("You're all caught up")
                .font(.system(size: 14, weight: .medium))
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
                CompletedCardView(item: item, onTap: onTap)
            }
        }
    }

    // MARK: - View All Button

    private var viewAllButton: some View {
        Button {
            onViewAll()
        } label: {
            HStack(spacing: 8) {
                Text("View all completed tasks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.3))

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.3))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Change cursor to pointer on hover
        }
    }
}

// MARK: - Completed Card View

private struct CompletedCardView: View {
    let item: CompletedItem
    let onTap: (CompletedItem) -> Void

    @State private var isHovered = false
    @State private var pulseAnimation = false

    var body: some View {
        Button {
            onTap(item)
        } label: {
            ZStack(alignment: .topTrailing) {
                // Main card content
                HStack(spacing: 16) {
                    // Output category icon
                    outputIconView(type: item.outputType)

                    VStack(alignment: .leading, spacing: 8) {
                        // Output type badge
                        outputBadgeView(type: item.outputType)

                        // Output title
                        Text(item.outputTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.2))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Employee and timestamp
                        HStack(spacing: 8) {
                            Text(item.employee.emoji)
                                .font(.system(size: 14))

                            Text(item.employee.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.4))

                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.4))

                            Text(relativeTimeString(from: item.completedAt))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(white: 0.4))
                        }
                    }

                    Spacer()
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

                // Unseen indicator dot
                if item.unseen {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .opacity(pulseAnimation ? 0.5 : 1.0)
                        .padding(16)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                pulseAnimation = true
                            }
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Output Icon View

    @ViewBuilder
    private func outputIconView(type: OutputType) -> some View {
        let config = outputTypeConfig(type)

        RoundedRectangle(cornerRadius: 12)
            .fill(config.color)
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: config.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Output Badge View

    @ViewBuilder
    private func outputBadgeView(type: OutputType) -> some View {
        let config = outputTypeConfig(type)

        Text(config.label.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(config.color.opacity(0.8))
            )
    }

    // MARK: - Helpers

    private func outputTypeConfig(_ type: OutputType) -> (color: Color, icon: String, label: String) {
        switch type {
        case .website:
            return (Color.teal, "globe", "Website")
        case .document:
            return (Color.purple, "doc.text", "Document")
        case .image:
            return (Color.orange, "photo", "Image")
        case .file:
            return (Color.blue, "doc", "File")
        case .presentation:
            return (Color.pink, "rectangle.on.rectangle.angled", "Presentation")
        case .spreadsheet:
            return (Color.green, "tablecells", "Spreadsheet")
        case .video:
            return (Color.red, "play.rectangle.fill", "Video")
        case .audio:
            return (Color.purple, "waveform", "Audio")
        case .code:
            return (Color.indigo, "curlybraces", "Code")
        case .unknown:
            return (Color.gray, "questionmark", "Unknown")
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

    let items: [CompletedItem] = [
        CompletedItem(
            id: "1",
            employee: employee1,
            outputTitle: "New Landing Page Design",
            outputType: .website,
            completedAt: Date().addingTimeInterval(-1800), // 30 min ago
            unseen: true
        ),
        CompletedItem(
            id: "2",
            employee: employee2,
            outputTitle: "API Documentation",
            outputType: .document,
            completedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            unseen: true
        ),
        CompletedItem(
            id: "3",
            employee: employee1,
            outputTitle: "Product Screenshots",
            outputType: .image,
            completedAt: Date().addingTimeInterval(-14400), // 4 hours ago
            unseen: true
        ),
    ]

    ZStack {
        Color.blue.opacity(0.1).ignoresSafeArea()
        RecentlyCompletedSection(
            items: items,
            hasMore: true,
            onTap: { item in
                print("Tapped item: \(item.id)")
            },
            onMarkAllSeen: {
                print("Mark all as seen")
            },
            onViewAll: {
                print("View all tapped")
            }
        )
        .padding(32)
    }
    .frame(width: 500, height: 600)
}
