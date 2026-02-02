import Foundation

/// Manages employee state. Phase A: returns mock data.
/// Phase B: calls workforce.employees.list via gateway.
@Observable
@MainActor
final class EmployeeService {
    static let shared = EmployeeService()

    var employees: [Employee] = Employee.mockEmployees
    var isLoading = false

    func fetchEmployees() async {
        self.isLoading = true
        // Phase A: mock data. Phase B: gateway call.
        self.employees = Employee.mockEmployees
        self.isLoading = false
    }

    func employee(byId id: String) -> Employee? {
        self.employees.first { $0.id == id }
    }
}
