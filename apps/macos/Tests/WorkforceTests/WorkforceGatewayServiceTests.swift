import Testing

@testable import Workforce

@Suite("WorkforceGatewayService.ConnectionState")
struct ConnectionStateTests {
    @Test("disconnected is not connected")
    func disconnected() {
        let state = WorkforceGatewayService.ConnectionState.disconnected
        #expect(!state.isConnected)
    }

    @Test("connecting is not connected")
    func connecting() {
        let state = WorkforceGatewayService.ConnectionState.connecting
        #expect(!state.isConnected)
    }

    @Test("connected is connected")
    func connected() {
        let state = WorkforceGatewayService.ConnectionState.connected(version: "1.0")
        #expect(state.isConnected)
    }

    @Test("error is not connected")
    func error() {
        let state = WorkforceGatewayService.ConnectionState.error("timeout")
        #expect(!state.isConnected)
    }

    @Test("connected states with different versions are not equal")
    func versionEquality() {
        let a = WorkforceGatewayService.ConnectionState.connected(version: "1.0")
        let b = WorkforceGatewayService.ConnectionState.connected(version: "2.0")
        #expect(a != b)
    }

    @Test("same state values are equal")
    func equality() {
        #expect(WorkforceGatewayService.ConnectionState.disconnected == .disconnected)
        #expect(WorkforceGatewayService.ConnectionState.connecting == .connecting)
        #expect(WorkforceGatewayService.ConnectionState.connected(version: "1.0") == .connected(version: "1.0"))
        #expect(WorkforceGatewayService.ConnectionState.error("x") == .error("x"))
    }
}

@Suite("WorkforceGatewayError")
struct WorkforceGatewayErrorTests {
    @Test("notConnected has description")
    func notConnectedDescription() {
        let error = WorkforceGatewayError.notConnected
        #expect(error.localizedDescription == "Gateway not connected")
    }
}
