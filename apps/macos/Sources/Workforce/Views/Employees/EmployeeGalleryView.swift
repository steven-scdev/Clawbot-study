import SwiftUI

struct EmployeeGalleryView: View {
    var employeeService: EmployeeService
    var onSelect: (Employee) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        Group {
            if self.employeeService.isLoading {
                ProgressView("Loading employees…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.employeeService.employees.isEmpty {
                self.emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: self.columns, spacing: 16) {
                        ForEach(self.employeeService.employees) { employee in
                            EmployeeCardView(employee: employee)
                                .onTapGesture {
                                    self.onSelect(employee)
                                }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Employees")
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
