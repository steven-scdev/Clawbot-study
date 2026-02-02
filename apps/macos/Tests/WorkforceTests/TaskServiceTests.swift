import Foundation
import Testing

@testable import Workforce

@Suite("TaskService")
struct TaskServiceTests {
    @Test("computed properties filter by status")
    @MainActor
    func filteredLists() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = WorkforceTask.mockTasks
        #expect(service.activeTasks.count == 1) // running
        #expect(service.completedTasks.count == 1)
        #expect(service.failedTasks.count == 1)
    }

    @Test("updateTaskStatus changes status")
    @MainActor
    func updateStatus() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = [WorkforceTask.mockTasks[0]] // running task
        let id = service.tasks[0].id

        service.updateTaskStatus(id: id, status: .completed)
        #expect(service.tasks[0].status == .completed)
        #expect(service.tasks[0].progress == 1.0)
        #expect(service.tasks[0].completedAt != nil)
    }

    @Test("updateTaskStatus ignores missing ID")
    @MainActor
    func updateMissingId() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = WorkforceTask.mockTasks
        let countBefore = service.tasks.count
        service.updateTaskStatus(id: "nonexistent", status: .completed)
        #expect(service.tasks.count == countBefore)
    }

    @Test("appendActivity adds to correct task")
    @MainActor
    func appendActivity() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = [WorkforceTask.mockTasks[0]]
        let id = service.tasks[0].id
        let initialCount = service.tasks[0].activities.count

        let activity = TaskActivity(
            id: "test-activity",
            type: .text,
            message: "Hello",
            timestamp: Date())
        service.appendActivity(taskId: id, activity: activity)
        #expect(service.tasks[0].activities.count == initialCount + 1)
        #expect(service.tasks[0].activities.last?.message == "Hello")
    }

    @Test("appendActivity ignores missing task ID")
    @MainActor
    func appendActivityMissing() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = WorkforceTask.mockTasks
        let activity = TaskActivity(
            id: "test", type: .error, message: "fail", timestamp: Date())
        service.appendActivity(taskId: "nonexistent", activity: activity)
        // No crash, no change
        for task in service.tasks {
            #expect(!task.activities.contains(where: { $0.id == "test" }))
        }
    }

    @Test("empty service has no active/completed/failed tasks")
    @MainActor
    func emptyState() {
        let service = TaskService(gateway: WorkforceGateway())
        #expect(service.activeTasks.isEmpty)
        #expect(service.completedTasks.isEmpty)
        #expect(service.failedTasks.isEmpty)
    }
}
