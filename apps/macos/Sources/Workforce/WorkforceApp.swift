import AppKit
import OSLog
import SwiftUI

@main
struct WorkforceApp: App {
    private static let logger = Logger(subsystem: "ai.openclaw.workforce", category: "app")
    @State private var selectedItem: SidebarItem? = .employees
    @State private var gatewayService = WorkforceGatewayService.shared
    @State private var employeeService = EmployeeService.shared
    @State private var taskService = TaskService.shared

    init() {
        Self.logger.info("Workforce app launching")
        // Activate the app to bring windows to front
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("Workforce") {
            VStack(spacing: 0) {
                MainWindowView(
                    selection: self.$selectedItem,
                    gatewayService: self.gatewayService,
                    employeeService: self.employeeService,
                    taskService: self.taskService
                )
                StatusBarView(state: self.gatewayService.connectionState)
            }
            .frame(minWidth: 900, minHeight: 600)
            .task {
                await self.gatewayService.connect()
            }
        }
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(gatewayService: self.gatewayService)
        }
    }
}
