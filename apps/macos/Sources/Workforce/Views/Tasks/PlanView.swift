import SwiftUI

struct PlanView: View {
    let task: WorkforceTask
    let plan: PlanPayload
    let employee: Employee?
    var taskService: TaskService
    var onApproved: (WorkforceTask) -> Void
    var onCancel: () -> Void

    @State private var showFeedback = false
    @State private var feedback = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            Divider()
            self.planContent
            Divider()
            self.controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let employee {
                Text(employee.emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Proposed a plan for your review")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
        }
        .padding(20)
    }

    // MARK: - Plan Content

    private var planContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(self.task.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                    Text(self.plan.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                // Steps
                VStack(alignment: .leading, spacing: 12) {
                    Text("Steps")
                        .font(.headline)

                    ForEach(Array(self.plan.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.description)
                                    .font(.body)
                                if let time = step.estimatedTime {
                                    Text(time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let time = self.plan.estimatedTime {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Estimated: \(time)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if self.showFeedback {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback")
                            .font(.headline)
                        TextEditor(text: self.$feedback)
                            .font(.body)
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            Button("Cancel Task") {
                self.onCancel()
            }
            .buttonStyle(.bordered)

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if self.showFeedback {
                Button("Submit Feedback") {
                    Task { await self.reject() }
                }
                .buttonStyle(.bordered)
                .disabled(self.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || self.isSubmitting)
            } else {
                Button("Request Changes") {
                    withAnimation { self.showFeedback = true }
                }
                .buttonStyle(.bordered)
            }

            Button("Looks Good, Start") {
                Task { await self.approve() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.isSubmitting)
        }
        .padding(20)
    }

    // MARK: - Actions

    private func approve() async {
        self.isSubmitting = true
        self.errorMessage = nil
        do {
            let updated = try await self.taskService.approvePlan(taskId: self.task.id)
            self.onApproved(updated)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }

    private func reject() async {
        self.isSubmitting = true
        self.errorMessage = nil
        do {
            let updated = try await self.taskService.rejectPlan(
                taskId: self.task.id,
                feedback: self.feedback.trimmingCharacters(in: .whitespacesAndNewlines))
            // Rejection returns a new plan — stay in planning state
            self.onApproved(updated)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isSubmitting = false
    }
}
