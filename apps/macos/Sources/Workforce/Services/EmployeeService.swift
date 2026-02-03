import Foundation
import Logging
import OpenClawKit
import OpenClawProtocol

/// Manages employee state. Calls workforce.employees.list via gateway,
/// falls back to mock data if plugin is not loaded.
@Observable
@MainActor
final class EmployeeService {
    static let shared = EmployeeService()

    var employees: [Employee] = Employee.mockEmployees
    var isLoading = false

    private let gateway: WorkforceGateway
    private let logger = Logger(label: "ai.openclaw.workforce.employees")
    private var statusTask: Task<Void, Never>?

    init(gateway: WorkforceGateway = WorkforceGatewayService.shared.gateway) {
        self.gateway = gateway
    }

    func fetchEmployees() async {
        self.isLoading = true
        do {
            let response: EmployeeListResponse = try await self.gateway.requestDecoded(
                method: "workforce.employees.list")
            self.employees = response.employees
            self.logger.info("Loaded \(response.employees.count) employees from gateway")
        } catch {
            self.logger.warning("Gateway fetch failed, using mock data: \(error.localizedDescription)")
            if self.employees.isEmpty {
                self.employees = Employee.mockEmployees
            }
        }
        self.isLoading = false
    }

    func employee(byId id: String) -> Employee? {
        self.employees.first { $0.id == id }
    }

    /// Subscribe to real-time employee status events from the gateway.
    func startStatusListener() {
        self.statusTask?.cancel()
        self.statusTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.gateway.subscribe()
            for await push in stream {
                guard !Task.isCancelled else { break }
                guard case let .event(frame) = push,
                      frame.event == "workforce.employee.status"
                else { continue }
                await MainActor.run {
                    self.handleStatusEvent(frame)
                }
            }
        }
    }

    func stopStatusListener() {
        self.statusTask?.cancel()
        self.statusTask = nil
    }

    private func handleStatusEvent(_ frame: EventFrame) {
        guard let payload = frame.payload?.value as? [String: Any],
              let employeeId = payload["employeeId"] as? String,
              let statusRaw = payload["status"] as? String,
              let index = self.employees.firstIndex(where: { $0.id == employeeId })
        else { return }
        self.employees[index].status = EmployeeStatus(rawValue: statusRaw) ?? .unknown
        self.employees[index].currentTaskId = payload["currentTaskId"] as? String
    }
}

private struct EmployeeListResponse: Codable {
    let employees: [Employee]
}
