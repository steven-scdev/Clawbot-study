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

    @Test("fetchEmployees returns mock data")
    @MainActor
    func fetch() async {
        let service = EmployeeService()
        service.employees = []
        await service.fetchEmployees()
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
}
