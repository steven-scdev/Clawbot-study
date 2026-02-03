import SwiftUI

/// Unified chat view that replaces the old TaskProgressView for chat-initiated tasks.
/// Shows conversation bubbles, streaming agent thinking, and a floating input pill
/// for follow-up messages — all on top of the animated blob background.
struct TaskChatView: View {
    let employee: Employee
    let taskId: String
    var taskService: TaskService
    var onBack: () -> Void

    @State private var messageText = ""
    @State private var blobPhase: CGFloat = 0

    private var task: WorkforceTask? {
        self.taskService.tasks.first(where: { $0.id == self.taskId })
    }

    /// Whether the agent is actively working (running + no recent text is the latest).
    private var isAgentWorking: Bool {
        guard let task else { return false }
        guard task.status == .running || task.status == .pending else { return false }
        return true
    }

    /// Convert task activities into displayable chat messages.
    private var chatMessages: [ChatMessage] {
        guard let task else { return [] }
        var messages: [ChatMessage] = []

        for activity in task.activities {
            switch activity.type {
            case .userMessage:
                messages.append(ChatMessage(
                    id: activity.id,
                    role: .user,
                    content: activity.message,
                    timestamp: activity.timestamp
                ))
            case .text:
                guard !activity.message.isEmpty else { continue }
                messages.append(ChatMessage(
                    id: activity.id,
                    role: .assistant,
                    content: activity.message,
                    timestamp: activity.timestamp
                ))
            case .completion:
                messages.append(ChatMessage(
                    id: activity.id,
                    role: .system,
                    content: "Task completed",
                    timestamp: activity.timestamp
                ))
            case .error:
                messages.append(ChatMessage(
                    id: activity.id,
                    role: .error,
                    content: activity.message,
                    timestamp: activity.timestamp
                ))
            case .thinking, .toolCall, .toolResult, .unknown:
                // Internal activities — shown in AgentThinkingStreamView, not as bubbles
                continue
            }
        }

        return messages
    }

    /// Recent internal activities for the thinking stream overlay.
    private var recentInternalActivities: [TaskActivity] {
        guard let task else { return [] }
        return task.activities.filter { activity in
            switch activity.type {
            case .thinking, .toolCall, .toolResult:
                return true
            default:
                return false
            }
        }
    }

    /// Show typing indicator when agent is working and the last visible thing
    /// is not already a text response (i.e. agent is still thinking/using tools).
    private var showTypingIndicator: Bool {
        guard self.isAgentWorking else { return false }
        guard let task else { return false }
        guard let lastActivity = task.activities.last else { return true }
        return lastActivity.type != .text
    }

    var body: some View {
        ZStack {
            BlobBackgroundView(blobPhase: self.$blobPhase)

            VStack(spacing: 0) {
                ChatHeaderView(
                    employee: self.employee,
                    taskDescription: self.task?.description ?? "",
                    onBack: self.onBack
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(self.chatMessages) { msg in
                                ChatBubbleView(
                                    message: msg,
                                    employeeName: self.employee.name
                                )
                                .id(msg.id)
                            }

                            if !self.recentInternalActivities.isEmpty, self.isAgentWorking {
                                AgentThinkingStreamView(activities: self.recentInternalActivities)
                                    .id("thinking-stream")
                            }

                            if self.showTypingIndicator {
                                ChatBubbleView.typingBubble(employeeName: self.employee.name)
                                    .id("typing-indicator")
                            }

                            // Bottom spacer for input pill clearance
                            Color.clear.frame(height: 100)
                                .id("bottom-anchor")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: self.chatMessages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: self.recentInternalActivities.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                }

                // Floating input pill
                ChatInputPill(
                    text: self.$messageText,
                    placeholder: "Send a message to \(self.employee.name)...",
                    onSubmit: self.sendMessage
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                self.blobPhase = 1
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() async {
        let text = self.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        self.messageText = ""
        await self.taskService.sendFollowUp(taskId: self.taskId, message: text)
    }
}
