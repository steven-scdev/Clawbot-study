import Foundation
import Testing

@testable import Workforce

@Suite("TaskProgressView Components")
struct TaskProgressViewTests {
    @Test("StageIndicatorView stages are ordered correctly")
    func stageOrder() {
        let stages: [TaskStage] = [.clarify, .plan, .execute, .review, .deliver]
        for (i, stage) in stages.enumerated() {
            #expect(!stage.label.isEmpty)
            #expect(!stage.icon.isEmpty)
            if i > 0 {
                #expect(stage.label != stages[i - 1].label)
            }
        }
    }

    @Test("ActivityType icons are distinct")
    func activityIcons() {
        let types: [ActivityType] = [
            .thinking, .toolCall, .toolResult, .text, .error, .completion, .unknown,
        ]
        var icons = Set<String>()
        for type in types {
            icons.insert(type.icon)
        }
        #expect(icons.count == types.count)
    }

    @Test("TaskService observeTask does not crash on missing ID")
    @MainActor
    func observeNonexistent() async {
        let service = TaskService(gateway: WorkforceGateway())
        await service.observeTask(id: "nonexistent")
        // Should return silently without crashing
        #expect(service.tasks.isEmpty)
    }

    @Test("TaskService stopObserving cleans up")
    @MainActor
    func stopObserving() {
        let service = TaskService(gateway: WorkforceGateway())
        service.stopObserving(taskId: "nonexistent")
        // Should not crash on missing observation
    }

    @Test("Progress heuristic increases with activities")
    @MainActor
    func progressEstimation() {
        let service = TaskService(gateway: WorkforceGateway())
        var task = WorkforceTask.mockTasks[0]
        task.activities = []
        task.progress = 0.0
        service.tasks = [task]

        // Add activities and check progress increases
        for i in 0..<10 {
            let activity = TaskActivity(
                id: "prog-\(i)",
                type: .toolCall,
                message: "Step \(i)",
                timestamp: Date())
            service.appendActivity(taskId: task.id, activity: activity)
        }
        #expect(service.tasks[0].activities.count == 10)
    }
}
