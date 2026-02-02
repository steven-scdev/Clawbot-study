import SwiftUI

struct TaskDashboardView: View {
    var taskService: TaskService
    var employeeService: EmployeeService
    var onSelectTask: (WorkforceTask) -> Void

    var body: some View {
        Group {
            if self.taskService.tasks.isEmpty {
                ContentPlaceholderView(
                    title: "No Tasks Yet",
                    subtitle: "Assign a task from the Employee Gallery",
                    icon: "list.bullet.clipboard")
            } else {
                self.taskList
            }
        }
        .navigationTitle("Tasks")
    }

    private var taskList: some View {
        List {
            if !self.taskService.activeTasks.isEmpty {
                Section("Active") {
                    ForEach(self.taskService.activeTasks) { task in
                        self.row(for: task)
                    }
                }
            }

            if !self.taskService.completedTasks.isEmpty {
                Section("Completed") {
                    ForEach(self.taskService.completedTasks) { task in
                        self.row(for: task)
                    }
                }
            }

            if !self.taskService.failedTasks.isEmpty {
                Section("Failed") {
                    ForEach(self.taskService.failedTasks) { task in
                        self.row(for: task)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func row(for task: WorkforceTask) -> some View {
        Button {
            self.onSelectTask(task)
        } label: {
            TaskRowView(
                task: task,
                employee: self.employeeService.employee(byId: task.employeeId))
        }
        .buttonStyle(.plain)
    }
}
