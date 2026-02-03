import SwiftUI

// MARK: - Filter Enum

private enum TaskFilter: String, CaseIterable {
    case all = "All Tasks"
    case active = "Active"
    case completed = "Completed"
    case failed = "Failed"
}

// MARK: - Task Dashboard View

struct TaskDashboardView: View {
    var taskService: TaskService
    var employeeService: EmployeeService
    var onSelectTask: (WorkforceTask) -> Void

    @State private var searchText = ""
    @State private var blobPhase: CGFloat = 0
    @State private var activeFilter: TaskFilter = .all

    private var filteredTasks: [WorkforceTask] {
        var tasks = self.taskService.tasks

        // Apply filter
        switch self.activeFilter {
        case .all:
            break
        case .active:
            tasks = tasks.filter { $0.status == .running || $0.status == .pending }
        case .completed:
            tasks = tasks.filter { $0.status == .completed }
        case .failed:
            tasks = tasks.filter { $0.status == .failed }
        }

        // Apply search
        if !self.searchText.isEmpty {
            let query = self.searchText.lowercased()
            tasks = tasks.filter { task in
                task.description.lowercased().contains(query)
                    || (self.employeeService.employee(byId: task.employeeId)?.name
                        .lowercased().contains(query) ?? false)
            }
        }

        return tasks
    }

    var body: some View {
        Group {
            if self.taskService.tasks.isEmpty {
                ContentPlaceholderView(
                    title: "No Tasks Yet",
                    subtitle: "Assign a task from the Employee Gallery",
                    icon: "list.bullet.clipboard")
            } else {
                self.glassContent
            }
        }
        .task { await self.taskService.fetchTasks() }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                self.blobPhase = 1
            }
        }
    }

    private var glassContent: some View {
        ZStack {
            BlobBackgroundView(blobPhase: self.$blobPhase)

            VStack(spacing: 0) {
                self.headerSection
                self.taskListSection
            }

            // Floating bottom bar (disabled for now)
            // VStack {
            //     Spacer()
            //     self.floatingBottomBar
            // }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row
            HStack {
                Text("Global History")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(white: 0.2))

                Spacer()

                HStack(spacing: 8) {
                    self.headerIconButton(icon: "calendar")
                    self.headerIconButton(icon: "arrow.down.circle")
                }
            }

            // Search + filters row
            HStack(spacing: 12) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.45))

                    TextField("Search global tasks...", text: self.$searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .frame(maxWidth: 280)

                // Filter pills
                HStack(spacing: 8) {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        self.filterPill(filter)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private func headerIconButton(icon: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.4))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func filterPill(_ filter: TaskFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.activeFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    self.activeFilter == filter ? .white : Color(white: 0.4)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    self.activeFilter == filter
                        ? AnyShapeStyle(Color.blue)
                        : AnyShapeStyle(Color.white.opacity(0.4))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            self.activeFilter == filter
                                ? Color.clear
                                : Color.white.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: self.activeFilter == filter
                        ? Color.blue.opacity(0.3)
                        : Color.clear,
                    radius: 8
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task List

    private var taskListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(self.filteredTasks) { task in
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
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Floating Bottom Bar

    private var floatingBottomBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)

            Text("Search tasks or assign a new global task...")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.45))

            Spacer()

            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: Color.blue.opacity(0.3), radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(
            color: Color(red: 0.12, green: 0.15, blue: 0.53).opacity(0.12),
            radius: 20,
            y: 8
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
    }
}
