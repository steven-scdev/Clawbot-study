import Testing

@testable import Workforce

@Suite("Settings")
struct SettingsTests {
    @Test("SettingsTab has correct labels")
    func tabLabels() {
        #expect(SettingsTab.gateway.label == "Gateway")
        #expect(SettingsTab.folders.label == "Folders")
    }

    @Test("SettingsTab has correct icons")
    func tabIcons() {
        #expect(SettingsTab.gateway.icon == "network")
        #expect(SettingsTab.folders.icon == "folder")
    }

    @Test("SettingsTab allCases has both tabs")
    func allCases() {
        #expect(SettingsTab.allCases.count == 2)
    }

    @Test("SettingsTab is identifiable")
    func identifiable() {
        let ids = SettingsTab.allCases.map(\.id)
        #expect(Set(ids).count == SettingsTab.allCases.count)
    }

    @Test("ConnectionState equatable for status bar")
    func connectionStateEquality() {
        let state1 = WorkforceGatewayService.ConnectionState.connecting
        let state2 = WorkforceGatewayService.ConnectionState.connecting
        #expect(state1 == state2)

        let connected = WorkforceGatewayService.ConnectionState.connected(version: "2025.1")
        let connected2 = WorkforceGatewayService.ConnectionState.connected(version: "2025.2")
        #expect(connected != connected2)
    }
}
