import SwiftUI

struct EmployeeGalleryView: View {
    var employeeService: EmployeeService
    var onSelect: (Employee) -> Void

    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)
    ]

    private var filteredEmployees: [Employee] {
        if self.searchText.isEmpty {
            return self.employeeService.employees
        }
        let query = self.searchText.lowercased()
        return self.employeeService.employees.filter { employee in
            employee.name.lowercased().contains(query)
                || employee.title.lowercased().contains(query)
                || employee.capabilities.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        Group {
            if self.employeeService.isLoading {
                ProgressView("Loading employees...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.employeeService.employees.isEmpty {
                self.emptyState
            } else {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // Header
                        GalleryHeaderView(
                            employeeCount: self.filteredEmployees.count,
                            searchText: self.$searchText
                        )

                        Divider()
                            .overlay(Color.white.opacity(0.1))

                        // Grid
                        ScrollView {
                            LazyVGrid(columns: self.columns, spacing: 20) {
                                ForEach(self.filteredEmployees) { employee in
                                    EmployeeCardView(
                                        employee: employee,
                                        onAssign: {
                                            self.onSelect(employee)
                                        }
                                    )
                                    .onTapGesture {
                                        self.onSelect(employee)
                                    }
                                }
                            }
                            .padding(24)
                            .padding(.bottom, 60)
                        }
                    }

                    // Floating new agent button
                    NewAgentButton()
                        .padding(.bottom, 20)
                }
            }
        }
        .task {
            await self.employeeService.fetchEmployees()
        }
    }

    private var emptyState: some View {
        ContentPlaceholderView(
            title: "No Employees",
            subtitle: "No employees configured. Check settings.",
            icon: "person.3"
        )
    }
}
