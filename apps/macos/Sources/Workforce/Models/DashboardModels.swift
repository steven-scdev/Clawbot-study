//
//  DashboardModels.swift
//  Workforce
//
//  Dashboard-specific data models for transforming WorkforceTask into view-ready items.
//

import Foundation

/// Action type for tasks requiring user attention in the dashboard.
enum ActionType: String {
    case clarification = "clarification"
    case planApproval = "plan_approval"
    case outputReview = "output_review"
}

/// Dashboard item representing a task that needs user attention (clarification, plan approval, or output review).
struct NeedsAttentionItem: Identifiable {
    /// Task ID (matches WorkforceTask.id)
    let id: String

    /// Target navigation state for this attention item
    let taskState: TaskFlowState

    /// Employee assigned to this task
    let employee: Employee

    /// Type of action required from the user
    let actionType: ActionType

    /// Context message (question text, "Plan ready", "Output ready")
    let message: String

    /// When the task entered this state
    let timestamp: Date
}

/// Dashboard item representing an actively executing task with stage progress.
struct InProgressItem: Identifiable {
    /// Task ID (matches WorkforceTask.id)
    let id: String

    /// Employee assigned to this task
    let employee: Employee

    /// Task description or title
    let taskDescription: String

    /// Current execution stage for progress indicator
    let currentStage: TaskStage

    /// Time elapsed since task started
    let elapsedTime: TimeInterval
}

/// Dashboard item representing a completed task output that the user hasn't seen yet.
struct CompletedItem: Identifiable {
    /// Task ID (matches WorkforceTask.id)
    let id: String

    /// Employee who completed this task
    let employee: Employee

    /// Title of the completed output
    let outputTitle: String

    /// Category/type of output (for icon and color)
    let outputType: OutputType

    /// When the task was completed
    let completedAt: Date

    /// Whether this item is unseen (always true in recently completed section)
    let unseen: Bool
}

// MARK: - WorkforceTask Extensions

extension WorkforceTask {
    /// Transform task into a NeedsAttentionItem if it requires user action.
    /// Returns nil if task doesn't need attention (not in clarify/plan/review stage or completed).
    func needsAttention(employee: Employee) -> NeedsAttentionItem? {
        // Clarification stage
        if self.status == .running, self.stage == .clarify {
            // Create empty clarification payload - will be populated from real data
            let emptyPayload = ClarificationPayload(questions: [])
            return NeedsAttentionItem(
                id: self.id,
                taskState: .clarifying(task: self, questions: emptyPayload),
                employee: employee,
                actionType: .clarification,
                message: "Needs clarification",
                timestamp: self.createdAt
            )
        }

        // Plan approval stage
        if self.status == .running, self.stage == .plan {
            // Create empty plan payload - will be populated from real data
            let emptyPlan = PlanPayload(summary: "", steps: [], estimatedTime: nil)
            return NeedsAttentionItem(
                id: self.id,
                taskState: .planning(task: self, plan: emptyPlan),
                employee: employee,
                actionType: .planApproval,
                message: "Plan ready for approval",
                timestamp: self.createdAt
            )
        }

        // Review stage
        if self.status == .running, self.stage == .review {
            return NeedsAttentionItem(
                id: self.id,
                taskState: .reviewing(taskId: self.id),
                employee: employee,
                actionType: .outputReview,
                message: "Output ready for review",
                timestamp: self.createdAt
            )
        }

        // Completed tasks also need review
        if self.status == .completed {
            return NeedsAttentionItem(
                id: self.id,
                taskState: .reviewing(taskId: self.id),
                employee: employee,
                actionType: .outputReview,
                message: "Output ready for review",
                timestamp: self.completedAt ?? self.createdAt
            )
        }

        return nil
    }

    /// Transform task into an InProgressItem if it's actively executing.
    /// Returns nil if task is not in execute stage or pending status.
    func inProgressItem(employee: Employee) -> InProgressItem? {
        // Execute stage
        if self.status == .running, self.stage == .execute {
            let elapsed = Date().timeIntervalSince(self.createdAt)
            return InProgressItem(
                id: self.id,
                employee: employee,
                taskDescription: self.description,
                currentStage: .execute,
                elapsedTime: elapsed
            )
        }

        // Pending tasks
        if self.status == .pending {
            let elapsed = Date().timeIntervalSince(self.createdAt)
            return InProgressItem(
                id: self.id,
                employee: employee,
                taskDescription: self.description,
                currentStage: .clarify, // Pending tasks start at clarify
                elapsedTime: elapsed
            )
        }

        return nil
    }

    /// Transform task into a CompletedItem if it's finished and matches seen status.
    /// Returns nil if task is not completed.
    func completedItem(employee: Employee, seen: Bool) -> CompletedItem? {
        guard self.status == .completed else { return nil }

        // Extract output title from task output or use description
        let outputTitle = self.outputs.first?.title ?? self.description

        // Determine output type from outputs or default to .file
        let outputType: OutputType = self.outputs.first?.type ?? .file

        return CompletedItem(
            id: self.id,
            employee: employee,
            outputTitle: outputTitle,
            outputType: outputType,
            completedAt: self.completedAt ?? Date(),
            unseen: !seen
        )
    }
}
