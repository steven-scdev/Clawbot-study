import SwiftUI
import AppKit

struct MainWindowView: View {
    @Binding var selection: SidebarItem?
    @Binding var isSidebarCollapsed: Bool
    var gatewayService: WorkforceGatewayService
    var employeeService: EmployeeService
    var taskService: TaskService
    @State private var flowState: TaskFlowState = .idle
    @State private var showSettingsSheet = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selection: self.$selection,
                isCollapsed: self.$isSidebarCollapsed
            )

            ZStack(alignment: .leading) {
                Group {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(self.flowState == .idle ? Color.black.opacity(0.03) : Color.clear)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.08),
                                Color.black.opacity(0.02),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 12)
                    .allowsHitTesting(false)

                // Quick access to Settings if the app menu is unavailable for any reason
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            // Always present in-app Settings sheet to avoid reliance on menu routing.
                            self.showSettingsSheet = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help("Open Settings (⌘,)")
                    }
                    .padding([.top, .trailing], 10)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: self.$showSettingsSheet) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Close") { self.showSettingsSheet = false }
                        .keyboardShortcut(.cancelAction)
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                }
                SettingsView(gatewayService: self.gatewayService)
                    .frame(width: 500, height: 400)
            }
        }
        .onChange(of: self.selection) { _, _ in
            if self.flowState != .idle {
                self.flowState = .idle
            }
        }
        // Disabled auto-transition to keep users in .chatting state with inline artifacts
        // .onChange(of: self.activeTaskStatus) { _, newStatus in
        //     if case let .executing(taskId) = self.flowState, newStatus == .completed {
        //         self.flowState = .reviewing(taskId: taskId)
        //     }
        // }
    }

    @ViewBuilder
    private var connectedDetail: some View {
        switch self.flowState {
        case .idle:
            if let selection {
                self.detailView(for: selection)
            } else {
                ContentPlaceholderView(
                    title: "Workforce",
                    subtitle: "Select an item from the sidebar",
                    icon: "person.3.fill"
                )
            }

        case let .input(employee):
            TaskInputView(
                employee: employee,
                taskService: self.taskService,
                onTaskSubmitted: { task in
                    Task { await self.taskService.observeTask(id: task.id) }
                    self.flowState = .chatting(employee: employee, taskId: task.id)
                },
                onCancel: {
                    self.flowState = .idle
                })

        case let .chatting(employee, taskId):
            TaskChatView(
                employee: employee,
                taskId: taskId,
                taskService: self.taskService,
                onBack: {
                    self.flowState = .idle
                })

        case let .clarifying(task, questions):
            ClarificationView(
                task: task,
                questions: questions,
                employee: self.employeeService.employee(byId: task.employeeId),
                taskService: self.taskService,
                onComplete: { updatedTask in
                    // After clarification, move to planning or executing
                    if updatedTask.stage == .plan {
                        self.flowState = .executing(taskId: updatedTask.id)
                    } else {
                        Task { await self.taskService.observeTask(id: updatedTask.id) }
                        self.flowState = .executing(taskId: updatedTask.id)
                    }
                },
                onCancel: {
                    Task { await self.taskService.cancelTask(id: task.id) }
                    self.flowState = .idle
                })

        case let .planning(task, plan):
            PlanView(
                task: task,
                plan: plan,
                employee: self.employeeService.employee(byId: task.employeeId),
                taskService: self.taskService,
                onApproved: { updatedTask in
                    Task { await self.taskService.observeTask(id: updatedTask.id) }
                    self.flowState = .executing(taskId: updatedTask.id)
                },
                onCancel: {
                    Task { await self.taskService.cancelTask(id: task.id) }
                    self.flowState = .idle
                })

        case let .executing(taskId):
            if let task = self.taskService.tasks.first(where: { $0.id == taskId }) {
                TaskProgressView(
                    task: task,
                    employee: self.employeeService.employee(byId: task.employeeId),
                    taskService: self.taskService,
                    onDismiss: {
                        self.flowState = .idle
                        self.selection = .tasks
                    },
                    onReview: {
                        self.flowState = .reviewing(taskId: taskId)
                    })
            } else {
                ContentPlaceholderView(
                    title: "Task Not Found",
                    subtitle: "The task may have been removed",
                    icon: "exclamationmark.triangle"
                )
            }

        case let .reviewing(taskId):
            if let task = self.taskService.tasks.first(where: { $0.id == taskId }) {
                OutputReviewView(
                    task: task,
                    employee: self.employeeService.employee(byId: task.employeeId),
                    taskService: self.taskService,
                    onDone: {
                        self.flowState = .idle
                        self.selection = .tasks
                    },
                    onRevise: {
                        Task { await self.taskService.observeTask(id: taskId) }
                        self.flowState = .executing(taskId: taskId)
                    })
            } else {
                ContentPlaceholderView(
                    title: "Task Not Found",
                    subtitle: "The task may have been removed",
                    icon: "exclamationmark.triangle"
                )
            }
        }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard:
            ContentPlaceholderView(
                title: "Dashboard",
                subtitle: "Team overview and activity feed coming soon",
                icon: "square.grid.2x2"
            )
        case .employees:
            EmployeeGalleryView(
                employeeService: self.employeeService,
                onSelect: { employee in
                    self.flowState = .input(employee: employee)
                })
        case .tasks:
            TaskDashboardView(
                taskService: self.taskService,
                employeeService: self.employeeService,
                onSelectTask: { task in
                    if let employee = self.employeeService.employee(byId: task.employeeId) {
                        Task { await self.taskService.observeTask(id: task.id) }
                        self.flowState = .chatting(employee: employee, taskId: task.id)
                    } else {
                        // Fallback for tasks without a resolvable employee
                        if task.status == .completed {
                            self.flowState = .reviewing(taskId: task.id)
                        } else {
                            Task { await self.taskService.observeTask(id: task.id) }
                            self.flowState = .executing(taskId: task.id)
                        }
                    }
                })
        case .memoryBank:
            ContentPlaceholderView(
                title: "Memory Bank",
                subtitle: "Shared knowledge and learned patterns coming soon",
                icon: "brain.head.profile"
            )
        }
    }

    private var activeTaskStatus: TaskStatus? {
        guard case let .executing(taskId) = self.flowState else { return nil }
        return self.taskService.tasks.first(where: { $0.id == taskId })?.status
    }
}
