import Foundation
import Logging
import OpenClawKit
import OpenClawProtocol

/// Observable gateway service that bridges the `WorkforceGateway` actor to SwiftUI.
/// Manages connection lifecycle, state, and auto-reconnect.
@Observable
@MainActor
final class WorkforceGatewayService {
    static let shared = WorkforceGatewayService()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(version: String)
        case error(String)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    private(set) var connectionState: ConnectionState = .disconnected

    let gateway = WorkforceGateway()

    private var monitorTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private let logger = Logger(label: "ai.openclaw.workforce.gateway")

    func connect() async {
        self.reconnectTask?.cancel()
        self.reconnectTask = nil
        self.connectionState = .connecting

        do {
            let config = self.loadConfig()
            self.logger.info("Connecting to gateway at \(config.url)")
            try await self.gateway.connect(url: config.url, token: config.token, password: config.password)
            self.startMonitoring()
        } catch {
            self.logger.error("Connection failed: \(error.localizedDescription)")
            self.connectionState = .error(error.localizedDescription)
            self.scheduleReconnect()
        }
    }

    func disconnect() async {
        self.monitorTask?.cancel()
        self.monitorTask = nil
        self.reconnectTask?.cancel()
        self.reconnectTask = nil
        await self.gateway.shutdown()
        self.connectionState = .disconnected
    }

    private func startMonitoring() {
        self.monitorTask?.cancel()
        self.monitorTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = await self.gateway.subscribe()
            for await push in stream {
                guard !Task.isCancelled else { break }
                switch push {
                case let .snapshot(hello):
                    let version = hello.server["version"]?.value as? String ?? "unknown"
                    self.connectionState = .connected(version: version)
                    self.logger.info("Connected to gateway v\(version)")
                case .event:
                    break
                case .seqGap:
                    break
                }
            }
            guard !Task.isCancelled else { return }
            self.connectionState = .disconnected
            self.scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        self.reconnectTask?.cancel()
        self.reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.logger.info("Attempting reconnect")
            await self?.connect()
        }
    }

    private func loadConfig() -> (url: URL, token: String?, password: String?) {
        let port = UserDefaults.standard.integer(forKey: "workforceGatewayPort")
        let effectivePort = port > 0 ? port : 18789
        let url = URL(string: "ws://127.0.0.1:\(effectivePort)/ws")!
        let token = UserDefaults.standard.string(forKey: "workforceGatewayToken")
        return (url, token, nil)
    }
}
