import Foundation
import Logging
import OpenClawKit
import OpenClawProtocol

/// Manages task lifecycle. Phase A: local in-memory storage + chat.send.
/// Phase B: backed by workforce plugin task store.
@Observable
@MainActor
final class TaskService {
    static let shared = TaskService()

    var tasks: [WorkforceTask] = []

    private let gateway: WorkforceGateway
    private let logger = Logger(label: "ai.openclaw.workforce.tasks")
    private var observationTasks: [String: Task<Void, Never>] = [:]

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

    func submitTask(employeeId: String, description: String) async throws -> WorkforceTask {
        let sessionKey = "workforce-\(employeeId)-\(UUID().uuidString.prefix(8))"

        // Phase A: Send via existing chat.send gateway method
        let params: [String: AnyCodable] = [
            "message": AnyCodable(description),
            "sessionKey": AnyCodable(sessionKey),
        ]

        do {
            _ = try await self.gateway.request(method: "chat.send", params: params)
        } catch {
            self.logger.error("chat.send failed: \(error.localizedDescription)")
            throw error
        }

        let task = WorkforceTask(
            id: UUID().uuidString,
            employeeId: employeeId,
            description: description,
            status: .running,
            stage: .execute,
            progress: 0.0,
            sessionKey: sessionKey,
            createdAt: Date(),
            activities: [])
        self.tasks.insert(task, at: 0)
        self.logger.info("Task submitted: \(task.id) for employee \(employeeId)")
        return task
    }

    func cancelTask(id: String) async {
        guard let index = self.tasks.firstIndex(where: { $0.id == id }) else { return }
        let sessionKey = self.tasks[index].sessionKey
        do {
            _ = try await self.gateway.request(
                method: "chat.abort",
                params: ["sessionKey": AnyCodable(sessionKey)])
        } catch {
            self.logger.error("chat.abort failed: \(error.localizedDescription)")
        }
        self.tasks[index].status = .cancelled
    }

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

    /// Start observing gateway events for a task's session, mapping them to activities.
    func observeTask(id taskId: String) async {
        guard let task = self.tasks.first(where: { $0.id == taskId }) else { return }
        let sessionKey = task.sessionKey

        // Cancel any existing observation for this task
        self.observationTasks[taskId]?.cancel()

        let stream = await self.gateway.subscribe()
        self.observationTasks[taskId] = Task { [weak self] in
            for await push in stream {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                await MainActor.run {
                    self.handlePush(push, taskId: taskId, sessionKey: sessionKey)
                }
            }
        }
    }

    func stopObserving(taskId: String) {
        self.observationTasks[taskId]?.cancel()
        self.observationTasks[taskId] = nil
    }

    private func handlePush(_ push: GatewayPush, taskId: String, sessionKey: String) {
        guard case let .event(frame) = push else { return }

        // Filter events that belong to our session via payload
        if let payload = frame.payload?.value as? [String: Any],
           let eventSession = payload["sessionKey"] as? String,
           eventSession != sessionKey
        { return }

        guard let activity = self.mapEvent(frame) else { return }
        self.appendActivity(taskId: taskId, activity: activity)

        // Estimate progress from activity count (Phase A heuristic)
        if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            let count = Double(self.tasks[index].activities.count)
            // Asymptotic progress: approaches 0.95 but never reaches 1.0
            self.tasks[index].progress = min(1.0 - 1.0 / (1.0 + count * 0.1), 0.95)
        }

        // Handle completion/error events
        if frame.event == "chat.complete" || frame.event == "agent.complete" {
            self.updateTaskStatus(id: taskId, status: .completed)
            self.stopObserving(taskId: taskId)
        } else if frame.event == "chat.error" || frame.event == "agent.error" {
            if let payload = frame.payload?.value as? [String: Any],
               let message = payload["message"] as? String
            {
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    self.tasks[index].errorMessage = message
                }
            }
            self.updateTaskStatus(id: taskId, status: .failed)
            self.stopObserving(taskId: taskId)
        }
    }

    private func mapEvent(_ frame: EventFrame) -> TaskActivity? {
        let id = "activity-\(UUID().uuidString.prefix(8))"
        let now = Date()

        switch frame.event {
        case "chat.token", "agent.token":
            // Skip individual tokens — too noisy
            return nil

        case "chat.thinking", "agent.thinking":
            let message = self.extractString(from: frame.payload, key: "text") ?? "Thinking..."
            return TaskActivity(id: id, type: .thinking, message: message, timestamp: now)

        case "chat.tool_call", "agent.tool_call":
            let tool = self.extractString(from: frame.payload, key: "name") ?? "tool"
            let input = self.extractString(from: frame.payload, key: "input")
            return TaskActivity(
                id: id, type: .toolCall,
                message: "Using \(tool)",
                timestamp: now, detail: input)

        case "chat.tool_result", "agent.tool_result":
            let tool = self.extractString(from: frame.payload, key: "name") ?? "tool"
            return TaskActivity(
                id: id, type: .toolResult,
                message: "\(tool) finished",
                timestamp: now)

        case "chat.text", "agent.text":
            let text = self.extractString(from: frame.payload, key: "text") ?? ""
            guard !text.isEmpty else { return nil }
            return TaskActivity(id: id, type: .text, message: text, timestamp: now)

        case "chat.complete", "agent.complete":
            return TaskActivity(
                id: id, type: .completion,
                message: "Task complete",
                timestamp: now)

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
}
