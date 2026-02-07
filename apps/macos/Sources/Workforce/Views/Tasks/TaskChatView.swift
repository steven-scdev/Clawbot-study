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
    @State private var attachments: [URL] = []
    @State private var blobPhase: CGFloat = 0
    @State private var showArtifactPane = false
    @State private var selectedOutputId: String?
    @State private var showFanOut = false
    @State private var fanAnchorRect: CGRect = .zero
    /// Delays the dismiss-backdrop hit testing to prevent click bleed-through from the button.
    @State private var fanBackdropActive = false
    @State private var isArtifactExpanded = false
    @State private var artifactPaneRatio: CGFloat = 0.5
    @State private var isApproved = false

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
            case .thinking, .toolCall, .toolResult, .planning, .unknown:
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
            case .thinking, .toolCall, .toolResult, .planning:
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
            $0.type == .thinking || $0.type == .toolCall || $0.type == .planning
        })?.message ?? ""
    }

    var body: some View {
        ZStack {
            BlobBackgroundView(blobPhase: self.$blobPhase)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left pane: Chat — hidden when artifact is expanded
                    if !self.isArtifactExpanded {
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

                                        // Show thinking stream if we have recent internal activities
                                        if !self.recentInternalActivities.isEmpty, self.isAgentWorking {
                                            AgentThinkingStreamView(activities: self.recentInternalActivities)
                                                .id("thinking-stream")
                                        }

                                        // Show typing indicator when agent is working and last activity wasn't text
                                        if self.showTypingIndicator {
                                            ChatBubbleView.typingBubble(employeeName: self.employee.name)
                                                .id("typing-indicator")
                                        }

                                        // Fallback: show "working" status when agent is active but silent
                                        if self.isAgentWorking && self.recentInternalActivities.isEmpty && !self.showTypingIndicator {
                                            WorkingStatusView(employeeName: self.employee.name)
                                                .id("working-status")
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
                                .onChange(of: self.isAgentWorking) { _, _ in
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                                    }
                                }
                            }

                            // Floating input pill + artifact stack button
                            HStack(alignment: .bottom, spacing: 12) {
                                ChatInputPill(
                                    text: self.$messageText,
                                    attachments: self.$attachments,
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
                        .frame(width: self.showArtifactPane && !self.taskOutputs.isEmpty
                            ? geometry.size.width * (1.0 - self.artifactPaneRatio) - 4
                            : nil)

                        // Draggable divider (only when both panes visible)
                        if self.showArtifactPane, !self.taskOutputs.isEmpty {
                            PaneDivider(ratio: self.$artifactPaneRatio, totalWidth: geometry.size.width)
                        }
                    }

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
                                    self.isArtifactExpanded = false
                                    self.showArtifactPane = false
                                }
                            },
                            onApprove: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    self.isApproved = true
                                }
                            },
                            isExpanded: self.isArtifactExpanded,
                            isApproved: self.isApproved,
                            onExpand: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    self.isArtifactExpanded.toggle()
                                }
                            },
                            employeeName: self.employee.name,
                            avatarSystemName: self.employee.avatarSystemName,
                            latestActivityMessage: self.latestAgentActivity,
                            taskProgress: self.task?.progress ?? 0.0
                        )
                        .frame(width: self.isArtifactExpanded
                            ? nil
                            : geometry.size.width * self.artifactPaneRatio - 4)
                    }
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
                        self.showArtifactPane = true
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
                self.showArtifactPane = true
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                self.blobPhase = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentOutput)) { notification in
            guard let userInfo = notification.userInfo,
                  let notifTaskId = userInfo["taskId"] as? String,
                  let outputId = userInfo["outputId"] as? String,
                  notifTaskId == self.taskId else { return }

            // Switch to the presented output
            self.selectedOutputId = outputId

            // Open pane if not already showing
            if !self.showArtifactPane {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.showArtifactPane = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshOutput)) { notification in
            guard let userInfo = notification.userInfo,
                  let notifTaskId = userInfo["taskId"] as? String,
                  notifTaskId == self.taskId else { return }

            // Notify child views to refresh via increment of a refresh token
            // The ArtifactPaneView will observe this and trigger a reload
            NotificationCenter.default.post(
                name: .artifactRefreshRequested,
                object: nil,
                userInfo: ["taskId": self.taskId]
            )
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
        let filePaths = self.attachments.map(\.path)
        self.messageText = ""
        self.attachments = []

        // Store references for attached files before sending the message
        if !filePaths.isEmpty, let task = self.task {
            await self.taskService.addReferences(employeeId: task.employeeId, filePaths: filePaths)
        }

        await self.taskService.sendFollowUp(taskId: self.taskId, message: text)
    }
}

// MARK: - Working Status View

/// Shows a subtle status indicator when the agent is working but has no recent activity logs
private struct WorkingStatusView: View {
    let employeeName: String

    @State private var dotCount = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            Text("\(self.employeeName.uppercased()) IS WORKING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.5))
                .tracking(1.2)

            Text(self.dots)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 20, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.2))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 60)
        .task {
            await self.animateDots()
        }
        .onDisappear {
            self.timer?.invalidate()
        }
    }

    private var dots: String {
        String(repeating: ".", count: self.dotCount)
    }

    private func animateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                withAnimation {
                    self.dotCount = (self.dotCount + 1) % 4
                }
            }
        }
    }
}

// MARK: - Draggable Pane Divider

private struct PaneDivider: View {
    @Binding var ratio: CGFloat
    let totalWidth: CGFloat

    @State private var isDragging = false
    @GestureState private var dragStartRatio: CGFloat?

    private let handleWidth: CGFloat = 8
    private let minRatio: CGFloat = 0.25
    private let maxRatio: CGFloat = 0.75

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: self.handleWidth)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(self.isDragging ? 0.6 : 0.3))
                    .frame(width: 3, height: 40)
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating(self.$dragStartRatio) { _, state, _ in
                        if state == nil { state = self.ratio }
                    }
                    .onChanged { value in
                        self.isDragging = true
                        guard let startRatio = self.dragStartRatio else { return }
                        let delta = -value.translation.width / self.totalWidth
                        self.ratio = min(self.maxRatio, max(self.minRatio, startRatio + delta))
                    }
                    .onEnded { _ in
                        self.isDragging = false
                    }
            )
    }
}
