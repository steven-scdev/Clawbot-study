import SwiftUI

private struct FanAnchorPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

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
    @State private var showArtifactPane = false
    @State private var selectedOutputId: String?
    @State private var showFanOut = false
    @State private var fanAnchorRect: CGRect = .zero
    /// Delays the dismiss-backdrop hit testing to prevent click bleed-through from the button.
    @State private var fanBackdropActive = false

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

    /// Outputs for the current task
    private var taskOutputs: [TaskOutput] {
        guard let task else { return [] }
        return task.outputs
    }

    /// Currently selected output or most recent
    private var currentOutput: TaskOutput? {
        guard let task else { return nil }
        if let id = selectedOutputId {
            return task.outputs.first(where: { $0.id == id })
        }
        return task.outputs.last
    }

    /// Whether to show the approve button
    private var showApproveButton: Bool {
        guard let task else { return false }
        return task.status == .completed && !task.outputs.isEmpty
    }

    /// Latest internal activity message for the agent working card
    private var latestAgentActivity: String {
        guard let task else { return "" }
        return task.activities.last(where: {
            $0.type == .thinking || $0.type == .toolCall
        })?.message ?? ""
    }

    var body: some View {
        ZStack {
            BlobBackgroundView(blobPhase: self.$blobPhase)

            HStack(spacing: 0) {
                // Left pane: Chat
                VStack(spacing: 0) {
                    ChatHeaderView(
                        employee: self.employee,
                        taskDescription: self.task?.description ?? "",
                        taskStatus: self.task?.status ?? .running,
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

                    // Floating input pill + artifact stack button
                    HStack(alignment: .bottom, spacing: 12) {
                        ChatInputPill(
                            text: self.$messageText,
                            placeholder: "Send a message to \(self.employee.name)...",
                            onSubmit: self.sendMessage
                        )

                        if !self.taskOutputs.isEmpty {
                            ArtifactStackButton(
                                outputCount: self.taskOutputs.count,
                                onTap: {
                                    guard self.fanAnchorRect != .zero else { return }
                                    self.showFanOut.toggle()
                                    if self.showFanOut {
                                        // Enable backdrop hit testing after the click event resolves
                                        self.fanBackdropActive = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            self.fanBackdropActive = true
                                        }
                                    }
                                }
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: FanAnchorPreferenceKey.self,
                                        value: geo.frame(in: .named("chatContainer"))
                                    )
                                }
                            )
                            .padding(.bottom, 24)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right pane: Artifacts (conditional)
                if self.showArtifactPane, !self.taskOutputs.isEmpty {
                    ArtifactPaneView(
                        output: self.currentOutput,
                        allOutputs: self.taskOutputs,
                        showApproveButton: self.showApproveButton,
                        isTaskRunning: self.isAgentWorking,
                        taskService: self.taskService,
                        taskId: self.taskId,
                        onOutputSelect: { outputId in
                            self.selectedOutputId = outputId
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                self.showArtifactPane = false
                            }
                        },
                        onApprove: {
                            self.onBack()
                        },
                        employeeName: self.employee.name,
                        avatarSystemName: self.employee.avatarSystemName,
                        latestActivityMessage: self.latestAgentActivity,
                        taskProgress: self.task?.progress ?? 0.0
                    )
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            // Dismiss backdrop — separate from fan view, with delayed hit testing
            if self.showFanOut {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { self.closeFan() }
                    .allowsHitTesting(self.fanBackdropActive)
                    .zIndex(99)
            }

            // Fan-out overlay
            if self.showFanOut, self.fanAnchorRect != .zero {
                ArtifactStackFanView(
                    outputs: self.taskOutputs,
                    anchorPoint: CGPoint(x: self.fanAnchorRect.midX, y: self.fanAnchorRect.minY),
                    onSelect: { outputId in
                        self.closeFan()
                        self.selectedOutputId = outputId
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.showArtifactPane = true
                        }
                    }
                )
                .zIndex(100)
            }
        }
        .coordinateSpace(name: "chatContainer")
        .onPreferenceChange(FanAnchorPreferenceKey.self) { rect in
            self.fanAnchorRect = rect
        }
        .onChange(of: self.showArtifactPane) { _, isShowing in
            if isShowing { self.closeFan() }
        }
        .onChange(of: self.taskOutputs.count) { old, new in
            if old == 0, new > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.showArtifactPane = true
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                self.blobPhase = 1
            }
        }
    }

    // MARK: - Actions

    private func closeFan() {
        self.showFanOut = false
        self.fanBackdropActive = false
    }

    private func sendMessage() async {
        let text = self.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        self.messageText = ""
        await self.taskService.sendFollowUp(taskId: self.taskId, message: text)
    }
}
