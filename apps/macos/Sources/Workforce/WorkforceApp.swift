import AppKit
import OSLog
import SwiftUI

@main
struct WorkforceApp: App {
    private static let logger = Logger(subsystem: "ai.openclaw.workforce", category: "app")
    @State private var selectedItem: SidebarItem? = .employees
    @State private var isSidebarCollapsed = false
    @State private var gatewayService = WorkforceGatewayService.shared
    @State private var employeeService = EmployeeService.shared
    @State private var taskService = TaskService.shared

    init() {
        Self.logger.info("Workforce app launching")
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("Workforce") {
            ZStack {
                // Warm gradient wallpaper behind the glass shell
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.91, blue: 0.84),
                        Color(red: 0.88, green: 0.90, blue: 0.86),
                        Color(red: 0.85, green: 0.88, blue: 0.92),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Glass container shell
                VStack(spacing: 0) {
                    MainWindowView(
                        selection: self.$selectedItem,
                        isSidebarCollapsed: self.$isSidebarCollapsed,
                        gatewayService: self.gatewayService,
                        employeeService: self.employeeService,
                        taskService: self.taskService
                    )
                    StatusBarView(state: self.gatewayService.connectionState)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.55))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                .padding(6)
            }
            .background(WindowConfigurator())
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(.light)
            .task {
                // Establish gateway connection first so subsequent RPCs succeed
                await self.gatewayService.connect()
                // Prime the workforce plugin with a gateway method call so it captures broadcast
                await self.employeeService.fetchEmployees()
                await self.taskService.fetchTasks()
                // Start global listener after we have a live connection
                self.taskService.startGlobalListener()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(gatewayService: self.gatewayService)
        }
    }
}
