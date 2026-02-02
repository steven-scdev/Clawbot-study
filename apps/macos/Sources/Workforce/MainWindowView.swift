import SwiftUI

struct MainWindowView: View {
    @Binding var selection: SidebarItem?
    var gatewayService: WorkforceGatewayService
    var employeeService: EmployeeService
    var taskService: TaskService
    @State private var selectedEmployee: Employee?
    @State private var activeTaskId: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: self.$selection)
                .toolbar(content: self.toolbarContent)
        } detail: {
            if self.gatewayService.connectionState.isConnected {
                self.connectedDetail
            } else {
                GatewayNotRunningView(
                    state: self.gatewayService.connectionState,
                    onRetry: {
                        Task { await self.gatewayService.connect() }
                    })
            }
        }
    }

    private var activeTask: WorkforceTask? {
        guard let activeTaskId else { return nil }
        return self.taskService.tasks.first(where: { $0.id == activeTaskId })
    }

    @ViewBuilder
    private var connectedDetail: some View {
        if let activeTask {
            TaskProgressView(
                task: activeTask,
                employee: self.employeeService.employee(byId: activeTask.employeeId),
                taskService: self.taskService,
                onDismiss: {
                    self.activeTaskId = nil
                    self.selection = .tasks
                })
        } else if let selectedEmployee {
            TaskInputView(
                employee: selectedEmployee,
                taskService: self.taskService,
                onTaskSubmitted: { task in
                    Task { await self.taskService.observeTask(id: task.id) }
                    self.activeTaskId = task.id
                    self.selectedEmployee = nil
                },
                onCancel: {
                    self.selectedEmployee = nil
                })
        } else if let selection {
            self.detailView(for: selection)
        } else {
            ContentPlaceholderView(
                title: "Workforce",
                subtitle: "Select an item from the sidebar",
                icon: "person.3.fill"
            )
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            ConnectionStatusView(state: self.gatewayService.connectionState)
        }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .employees:
            EmployeeGalleryView(
                employeeService: self.employeeService,
                onSelect: { employee in
                    self.selectedEmployee = employee
                })
        case .tasks:
            TaskDashboardView(
                taskService: self.taskService,
                employeeService: self.employeeService,
                onSelectTask: { task in
                    Task { await self.taskService.observeTask(id: task.id) }
                    self.activeTaskId = task.id
                })
        case .settings:
            SettingsView(gatewayService: self.gatewayService)
        }
    }
}
