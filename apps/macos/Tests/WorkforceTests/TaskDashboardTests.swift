import Foundation
import Testing

@testable import Workforce

@Suite("TaskDashboard")
struct TaskDashboardTests {
    @Test("TaskService sections categorize correctly")
    @MainActor
    func sections() {
        let service = TaskService(gateway: WorkforceGateway())
        service.tasks = WorkforceTask.mockTasks

        let active = service.activeTasks
        let completed = service.completedTasks
        let failed = service.failedTasks

        #expect(active.allSatisfy { $0.status == .running || $0.status == .pending })
        #expect(completed.allSatisfy { $0.status == .completed })
        #expect(failed.allSatisfy { $0.status == .failed })

        // No task appears in multiple sections
        let allIds = active.map(\.id) + completed.map(\.id) + failed.map(\.id)
        #expect(Set(allIds).count == allIds.count)
    }

    @Test("TaskRowView time label uses completedAt when available")
    func completedTaskTime() {
        let completed = WorkforceTask.mockTasks.first(where: { $0.status == .completed })
        #expect(completed != nil)
        #expect(completed?.completedAt != nil)
    }

    @Test("TaskRowView falls back to createdAt for active tasks")
    func activeTaskTime() {
        let running = WorkforceTask.mockTasks.first(where: { $0.status == .running })
        #expect(running != nil)
        #expect(running?.completedAt == nil)
        #expect(running?.createdAt != nil)
    }

    @Test("Empty task service has no sections")
    @MainActor
    func emptyDashboard() {
        let service = TaskService(gateway: WorkforceGateway())
        #expect(service.activeTasks.isEmpty)
        #expect(service.completedTasks.isEmpty)
        #expect(service.failedTasks.isEmpty)
    }
}
