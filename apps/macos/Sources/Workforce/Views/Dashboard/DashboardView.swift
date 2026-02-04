//
//  DashboardView.swift
//  Workforce
//
//  Main dashboard container orchestrating scroll state, blob background animation, and three sections.
//

import SwiftUI

struct DashboardView: View {
    let taskService: TaskService
    let employeeService: EmployeeService
    let onNavigate: (TaskFlowState) -> Void
    let onViewAllCompleted: () -> Void

    @AppStorage("dashboard.seenTasks") private var seenTaskIdsString: String = ""

    var body: some View {
        ZStack {
            // Warm beige background matching the app theme
            Color(red: 0.91, green: 0.86, blue: 0.78)
                .ignoresSafeArea()

            // Main content
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView

                    // Needs Attention section (full-width)
                    NeedsAttentionSection(
                        items: needsAttentionItems,
                        onTap: handleAttentionTap
                    )

                    // Two-column layout: In Progress (left) + Recently Completed (right)
                    HStack(alignment: .top, spacing: 24) {
                        // In Progress (left column)
                        InProgressSection(
                            items: inProgressItems,
                            onTap: handleProgressTap
                        )
                        .frame(maxWidth: .infinity)

                        // Recently Completed (right column)
                        RecentlyCompletedSection(
                            items: displayedCompletedItems,
                            hasMore: hasMoreCompletedItems,
                            onTap: handleCompletedTap,
                            onMarkAllSeen: markAllAsSeen,
                            onViewAll: onViewAllCompleted
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(32)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Good morning, Alex")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(white: 0.2))

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(Color.blue.opacity(0.8))

                    Text(formattedDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    /// Filtered items needing user attention
    private var needsAttentionItems: [NeedsAttentionItem] {
        taskService.needsAttentionTasks.compactMap { task in
            guard let employee = employeeService.employee(byId: task.employeeId) else {
                return nil
            }
            return task.needsAttention(employee: employee)
        }
    }

    /// Filtered items in progress
    private var inProgressItems: [InProgressItem] {
        taskService.inProgressTasks.compactMap { task in
            guard let employee = employeeService.employee(byId: task.employeeId) else {
                return nil
            }
            return task.inProgressItem(employee: employee)
        }
    }

    /// Filtered completed items that haven't been seen
    private var recentlyCompletedItems: [CompletedItem] {
        let seenIds = seenTaskIds
        return taskService.completedTasks.compactMap { task in
            guard let employee = employeeService.employee(byId: task.employeeId) else {
                return nil
            }
            let isSeen = seenIds.contains(task.id)
            guard !isSeen else { return nil } // Only show unseen items
            return task.completedItem(employee: employee, seen: false)
        }
    }

    /// Limited to first 6 items for dashboard display
    private var displayedCompletedItems: [CompletedItem] {
        Array(recentlyCompletedItems.prefix(6))
    }

    /// Check if there are more than 6 completed items
    private var hasMoreCompletedItems: Bool {
        recentlyCompletedItems.count > 6
    }

    // MARK: - Seen Tracking

    /// Set of task IDs that have been marked as seen
    private var seenTaskIds: Set<String> {
        get {
            Set(seenTaskIdsString.split(separator: ",").map(String.init))
        }
        nonmutating set {
            var trimmed = newValue
            if trimmed.count > 100 {
                // Keep only the most recent 100
                trimmed = Set(Array(trimmed).sorted().suffix(100))
            }
            seenTaskIdsString = trimmed.joined(separator: ",")
        }
    }

    /// Mark a single task as seen
    private func markTaskAsSeen(taskId: String) {
        var seen = seenTaskIds
        seen.insert(taskId)
        seenTaskIds = seen
    }

    /// Mark all currently visible completed tasks as seen
    private func markAllAsSeen() {
        var seen = seenTaskIds
        seen.formUnion(recentlyCompletedItems.map(\.id))
        seenTaskIds = seen
    }

    // MARK: - Navigation Handlers

    /// Handle tap on attention item - mark as seen and navigate
    private func handleAttentionTap(item: NeedsAttentionItem) {
        markTaskAsSeen(taskId: item.id)
        onNavigate(item.taskState)
    }

    /// Handle tap on progress item - navigate to chat view
    private func handleProgressTap(item: InProgressItem) {
        onNavigate(.chatting(employee: item.employee, taskId: item.id))
    }

    /// Handle tap on completed item - mark as seen and navigate to review
    private func handleCompletedTap(item: CompletedItem) {
        markTaskAsSeen(taskId: item.id)
        onNavigate(.reviewing(taskId: item.id))
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter.string(from: Date())
    }
}

// MARK: - Preview

#Preview {
    let taskService = TaskService()
    let employeeService = EmployeeService()

    DashboardView(
        taskService: taskService,
        employeeService: employeeService,
        onNavigate: { state in
            print("Navigate to: \(state)")
        },
        onViewAllCompleted: {
            print("View all completed tapped")
        }
    )
    .frame(width: 1400, height: 900)
}
