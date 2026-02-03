import Foundation
import Logging
import OpenClawKit
import OpenClawProtocol

/// Manages task lifecycle via the workforce plugin's gateway methods.
/// Falls back to local-only operation when the plugin is unavailable.
@Observable
@MainActor
final class TaskService {
    static let shared = TaskService()

    var tasks: [WorkforceTask] = []
    var taskOutputs: [String: [TaskOutput]] = [:]

    private let gateway: WorkforceGateway
    private let logger = Logger(label: "ai.openclaw.workforce.tasks")
    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var globalListener: Task<Void, Never>?

    init(gateway: WorkforceGateway = WorkforceGatewayService.shared.gateway) {
        self.gateway = gateway
    }

    var activeTasks: [WorkforceTask] {
        self.tasks.filter { $0.status == .running || $0.status == .pending }
    }

    var completedTasks: [WorkforceTask] {
        self.tasks.filter { $0.status == .completed }
    }

    var failedTasks: [WorkforceTask] {
        self.tasks.filter { $0.status == .failed }
    }

    // MARK: - Task CRUD

    func submitTask(employeeId: String, description: String, attachments: [String] = []) async throws -> WorkforceTask {
        let params: [String: AnyCodable] = [
            "employeeId": AnyCodable(employeeId),
            "brief": AnyCodable(description),
            "attachments": AnyCodable(attachments),
        ]

        do {
            let response: TaskCreateResponse = try await self.gateway.requestDecoded(
                method: "workforce.tasks.create", params: params)
            self.tasks.insert(response.task, at: 0)
            self.logger.info("Task created: \(response.task.id) for \(employeeId)")

            // Subscribe to events BEFORE starting the agent so we don't miss any
            await self.observeTask(id: response.task.id)

            // Start the AI agent for this task
            await self.startAgent(sessionKey: response.task.sessionKey, message: description)
            if let index = self.tasks.firstIndex(where: { $0.id == response.task.id }) {
                self.tasks[index].status = .running
                self.tasks[index].stage = .execute
            }

            return response.task
        } catch {
            self.logger.warning("workforce.tasks.create failed, using local task: \(error.localizedDescription)")
            let task = WorkforceTask(
                id: UUID().uuidString,
                employeeId: employeeId,
                description: description,
                status: .pending,
                stage: .clarify,
                progress: 0.0,
                sessionKey: "workforce-\(employeeId)-\(UUID().uuidString.prefix(8))",
                createdAt: Date())
            self.tasks.insert(task, at: 0)
            return task
        }
    }

    func submitClarification(taskId: String, answers: [ClarificationAnswer]) async throws -> WorkforceTask {
        let answerDicts = answers.map { ["questionId": AnyCodable($0.questionId), "value": AnyCodable($0.value)] }
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "answers": AnyCodable(answerDicts),
        ]
        let response: TaskCreateResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.clarify", params: params)
        self.updateLocalTask(response.task)
        return response.task
    }

    func approvePlan(taskId: String) async throws -> WorkforceTask {
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "approved": AnyCodable(true),
        ]
        let response: TaskCreateResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.approve", params: params)
        self.updateLocalTask(response.task)

        // Start the agent for execution
        await self.startAgent(sessionKey: response.task.sessionKey, message: response.task.description)

        return response.task
    }

    func rejectPlan(taskId: String, feedback: String) async throws -> WorkforceTask {
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "approved": AnyCodable(false),
            "feedback": AnyCodable(feedback),
        ]
        let response: TaskCreateResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.approve", params: params)
        self.updateLocalTask(response.task)
        return response.task
    }

    func cancelTask(id: String) async {
        let params: [String: AnyCodable] = ["taskId": AnyCodable(id)]
        do {
            let response: TaskCreateResponse = try await self.gateway.requestDecoded(
                method: "workforce.tasks.cancel", params: params)
            self.updateLocalTask(response.task)
        } catch {
            self.logger.warning("workforce.tasks.cancel failed: \(error.localizedDescription)")
            // Fallback: update locally
            if let index = self.tasks.firstIndex(where: { $0.id == id }) {
                self.tasks[index].status = .cancelled
            }
        }
        self.stopObserving(taskId: id)
    }

    func requestRevision(taskId: String, feedback: String) async throws -> WorkforceTask {
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "feedback": AnyCodable(feedback),
        ]
        let response: TaskCreateResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.revise", params: params)
        self.updateLocalTask(response.task)

        // Re-start the agent with revision context (same session preserves history)
        await self.startAgent(
            sessionKey: response.task.sessionKey,
            message: "Revision requested:\n\(feedback)")

        return response.task
    }

    func openOutput(taskId: String, outputId: String) async {
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "outputId": AnyCodable(outputId),
        ]
        do {
            _ = try await self.gateway.request(method: "workforce.outputs.open", params: params)
        } catch {
            self.logger.warning("workforce.outputs.open failed: \(error.localizedDescription)")
        }
    }

    func revealOutput(taskId: String, outputId: String) async {
        let params: [String: AnyCodable] = [
            "taskId": AnyCodable(taskId),
            "outputId": AnyCodable(outputId),
        ]
        do {
            _ = try await self.gateway.request(method: "workforce.outputs.reveal", params: params)
        } catch {
            self.logger.warning("workforce.outputs.reveal failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Task Fetching

    func fetchTasks() async {
        do {
            let response: TaskListResponse = try await self.gateway.requestDecoded(
                method: "workforce.tasks.list")
            self.tasks = response.tasks
            self.logger.info("Loaded \(response.tasks.count) tasks from gateway")
        } catch {
            self.logger.warning("workforce.tasks.list failed: \(error.localizedDescription)")
        }
    }

    func fetchTask(id: String) async -> WorkforceTask? {
        let params: [String: AnyCodable] = ["taskId": AnyCodable(id)]
        do {
            let response: TaskCreateResponse = try await self.gateway.requestDecoded(
                method: "workforce.tasks.get", params: params)
            self.updateLocalTask(response.task)
            return response.task
        } catch {
            self.logger.warning("workforce.tasks.get failed: \(error.localizedDescription)")
            return self.tasks.first { $0.id == id }
        }
    }

    // MARK: - Status Helpers

    func updateTaskStatus(id: String, status: TaskStatus) {
        guard let index = self.tasks.firstIndex(where: { $0.id == id }) else { return }
        self.tasks[index].status = status
        if status == .completed {
            self.tasks[index].completedAt = Date()
            self.tasks[index].progress = 1.0
        }
    }

    func appendActivity(taskId: String, activity: TaskActivity) {
        guard let index = self.tasks.firstIndex(where: { $0.id == taskId }) else { return }
        self.tasks[index].activities.append(activity)
    }

    // MARK: - Event Observation

    /// Start a global listener for all workforce.task.* events.
    /// Automatically re-subscribes when the stream ends (e.g. after a disconnect/reconnect cycle).
    func startGlobalListener() {
        self.globalListener?.cancel()
        self.globalListener = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let stream = await self.gateway.subscribe()
                for await push in stream {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleWorkforcePush(push)
                    }
                }
                // Stream ended (disconnect). Brief pause before re-subscribing
                // so we don't spin while waiting for reconnection.
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopGlobalListener() {
        self.globalListener?.cancel()
        self.globalListener = nil
    }

    /// Start observing events for a specific task (legacy + workforce events).
    func observeTask(id taskId: String) async {
        guard self.tasks.contains(where: { $0.id == taskId }) else { return }

        self.observationTasks[taskId]?.cancel()
        let stream = await self.gateway.subscribe()
        self.observationTasks[taskId] = Task { [weak self] in
            for await push in stream {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                await MainActor.run {
                    self.handleWorkforcePush(push)
                }
            }
        }
    }

    func stopObserving(taskId: String) {
        self.observationTasks[taskId]?.cancel()
        self.observationTasks[taskId] = nil
    }

    // MARK: - Event Handling

    private func handleWorkforcePush(_ push: GatewayPush) {
        guard case let .event(frame) = push else { return }

        let payload = frame.payload?.value as? [String: Any] ?? [:]
        guard let taskId = payload["taskId"] as? String else {
            // Legacy event path: check for session-based routing
            self.handleLegacyPush(frame)
            return
        }

        switch frame.event {
        case "workforce.task.activity":
            if let actDict = payload["activity"] as? [String: Any] {
                let activity = TaskActivity(
                    id: actDict["id"] as? String ?? UUID().uuidString,
                    type: ActivityType(rawValue: actDict["type"] as? String ?? "") ?? .unknown,
                    message: actDict["message"] as? String ?? "",
                    timestamp: Date())
                self.appendActivity(taskId: taskId, activity: activity)
            }

        case "workforce.task.progress":
            if let progress = payload["progress"] as? Double,
               let index = self.tasks.firstIndex(where: { $0.id == taskId })
            {
                self.tasks[index].progress = progress
            }

        case "workforce.task.stage":
            if let stageStr = payload["stage"] as? String,
               let stage = TaskStage(rawValue: stageStr),
               let index = self.tasks.firstIndex(where: { $0.id == taskId })
            {
                self.tasks[index].stage = stage
            }

        case "workforce.task.output":
            if let outDict = payload["output"] as? [String: Any] {
                let output = TaskOutput(
                    id: outDict["id"] as? String ?? UUID().uuidString,
                    taskId: taskId,
                    type: OutputType(rawValue: outDict["type"] as? String ?? "") ?? .unknown,
                    title: outDict["title"] as? String ?? "Output",
                    filePath: outDict["filePath"] as? String,
                    url: outDict["url"] as? String,
                    createdAt: Date())
                self.taskOutputs[taskId, default: []].append(output)
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    self.tasks[index].outputs.append(output)
                }
            }

        case "workforce.task.completed":
            self.updateTaskStatus(id: taskId, status: .completed)
            self.stopObserving(taskId: taskId)

        case "workforce.task.failed":
            if let errorMsg = payload["error"] as? String,
               let index = self.tasks.firstIndex(where: { $0.id == taskId })
            {
                self.tasks[index].errorMessage = errorMsg
            }
            self.updateTaskStatus(id: taskId, status: .failed)
            self.stopObserving(taskId: taskId)

        default:
            break
        }
    }

    /// Handle legacy chat.*/agent.* events for backward compatibility.
    private func handleLegacyPush(_ frame: EventFrame) {
        guard let payload = frame.payload?.value as? [String: Any],
              let sessionKey = payload["sessionKey"] as? String
        else { return }

        guard let taskIndex = self.tasks.firstIndex(where: { $0.sessionKey == sessionKey }) else { return }
        let taskId = self.tasks[taskIndex].id

        let activity = self.mapLegacyEvent(frame)
        if let activity {
            self.appendActivity(taskId: taskId, activity: activity)
            let count = Double(self.tasks[taskIndex].activities.count)
            self.tasks[taskIndex].progress = min(1.0 - 1.0 / (1.0 + count * 0.1), 0.95)
        }

        if frame.event == "chat.complete" || frame.event == "agent.complete" {
            self.updateTaskStatus(id: taskId, status: .completed)
        } else if frame.event == "chat.error" || frame.event == "agent.error" {
            if let message = payload["message"] as? String {
                self.tasks[taskIndex].errorMessage = message
            }
            self.updateTaskStatus(id: taskId, status: .failed)
        }
    }

    private func mapLegacyEvent(_ frame: EventFrame) -> TaskActivity? {
        let id = "activity-\(UUID().uuidString.prefix(8))"
        let now = Date()

        switch frame.event {
        case "chat.token", "agent.token":
            return nil
        case "chat.thinking", "agent.thinking":
            let message = self.extractString(from: frame.payload, key: "text") ?? "Thinking..."
            return TaskActivity(id: id, type: .thinking, message: message, timestamp: now)
        case "chat.tool_call", "agent.tool_call":
            let tool = self.extractString(from: frame.payload, key: "name") ?? "tool"
            let input = self.extractString(from: frame.payload, key: "input")
            return TaskActivity(id: id, type: .toolCall, message: "Using \(tool)", timestamp: now, detail: input)
        case "chat.tool_result", "agent.tool_result":
            let tool = self.extractString(from: frame.payload, key: "name") ?? "tool"
            return TaskActivity(id: id, type: .toolResult, message: "\(tool) finished", timestamp: now)
        case "chat.text", "agent.text":
            let text = self.extractString(from: frame.payload, key: "text") ?? ""
            guard !text.isEmpty else { return nil }
            return TaskActivity(id: id, type: .text, message: text, timestamp: now)
        case "chat.complete", "agent.complete":
            return TaskActivity(id: id, type: .completion, message: "Task complete", timestamp: now)
        case "chat.error", "agent.error":
            let message = self.extractString(from: frame.payload, key: "message") ?? "An error occurred"
            return TaskActivity(id: id, type: .error, message: message, timestamp: now)
        default:
            return nil
        }
    }

    private func extractString(from payload: OpenClawProtocol.AnyCodable?, key: String) -> String? {
        guard let dict = payload?.value as? [String: Any] else { return nil }
        return dict[key] as? String
    }

    // MARK: - Agent Invocation

    /// Invoke the built-in `agent` gateway method to start an AI run for a workforce task.
    private func startAgent(sessionKey: String, message: String) async {
        let agentParams: [String: AnyCodable] = [
            "message": AnyCodable(message),
            "sessionKey": AnyCodable(sessionKey),
            "idempotencyKey": AnyCodable("wf-\(sessionKey)-\(UUID().uuidString.prefix(8))"),
        ]
        do {
            _ = try await self.gateway.request(method: "agent", params: agentParams)
            self.logger.info("Agent started for session: \(sessionKey)")
        } catch {
            self.logger.warning("Failed to start agent for \(sessionKey): \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func updateLocalTask(_ task: WorkforceTask) {
        if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
            self.tasks[index] = task
        } else {
            self.tasks.insert(task, at: 0)
        }
    }
}
