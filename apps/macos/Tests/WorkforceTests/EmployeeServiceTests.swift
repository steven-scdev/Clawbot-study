import Testing

@testable import Workforce

@Suite("EmployeeService")
struct EmployeeServiceTests {
    @Test("starts with mock employees")
    @MainActor
    func initialState() {
        let service = EmployeeService()
        #expect(service.employees.count == 3)
        #expect(!service.isLoading)
    }

    @Test("fetchEmployees falls back to mock data when gateway unavailable")
    @MainActor
    func fetchFallback() async {
        let service = EmployeeService()
        service.employees = []
        await service.fetchEmployees()
        #expect(service.employees.count == 3)
        #expect(!service.isLoading)
    }

    @Test("fetchEmployees preserves existing data when gateway unavailable and list not empty")
    @MainActor
    func fetchPreservesExisting() async {
        let service = EmployeeService()
        // Already has 3 mock employees
        #expect(service.employees.count == 3)
        await service.fetchEmployees()
        // Should keep existing data (not reset to empty)
        #expect(service.employees.count == 3)
        #expect(!service.isLoading)
    }

    @Test("employee(byId:) finds existing employee")
    @MainActor
    func findById() {
        let service = EmployeeService()
        let emma = service.employee(byId: "emma-web")
        #expect(emma != nil)
        #expect(emma?.name == "Emma")
    }

    @Test("employee(byId:) returns nil for missing ID")
    @MainActor
    func missingId() {
        let service = EmployeeService()
        let missing = service.employee(byId: "nonexistent")
        #expect(missing == nil)
    }

    @Test("mock employees have nil currentTaskId by default")
    @MainActor
    func currentTaskIdDefault() {
        let service = EmployeeService()
        for employee in service.employees {
            #expect(employee.currentTaskId == nil)
        }
    }
}
