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
        // Guard against re-entry: stale reconnect tasks or monitor cleanup
        // can call connect() while we're already mid-handshake.
        if case .connecting = self.connectionState { return }

        // Cancel the monitoring task BEFORE touching the gateway.
        // Without this, gateway.connect() shuts down the old actor which
        // finishes the monitor stream. The monitor then runs (the actor is
        // suspended at an await) and calls scheduleReconnect(), creating an
        // infinite cascade of competing reconnections — each one destroying
        // the connection the previous attempt just established.
        self.monitorTask?.cancel()
        self.monitorTask = nil

        // Don't cancel reconnectTask — we may be running inside it.
        // Cancelling would propagate to child tasks (URLSession WebSocket),
        // causing the handshake to fail with code 1001.
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
        // Read from ~/.openclaw/openclaw.json (the canonical gateway config)
        let (filePort, fileToken) = Self.readOpenClawConfig()

        // UserDefaults overrides let advanced users point at a different gateway
        let ud = UserDefaults.standard
        let udPort = ud.integer(forKey: "workforceGatewayPort")
        let udToken = ud.string(forKey: "workforceGatewayToken")
        let udPassword = ud.string(forKey: "workforceGatewayPassword")

        // Environment overrides are handy for local debugging and CI
        // OPENCLAW_GATEWAY_TOKEN / OPENCLAW_GATEWAY_PASSWORD mirror the CLI
        let env = ProcessInfo.processInfo.environment
        let envToken = env["OPENCLAW_GATEWAY_TOKEN"] ?? env["CLAWDBOT_GATEWAY_TOKEN"]
        let envPassword = env["OPENCLAW_GATEWAY_PASSWORD"] ?? env["CLAWDBOT_GATEWAY_PASSWORD"]

        let effectivePort = udPort > 0 ? udPort : (filePort ?? 18789)
        // Token/password precedence: UserDefaults -> env -> file
        let effectiveToken = udToken ?? envToken ?? fileToken
        let effectivePassword = udPassword ?? envPassword

        // Connect to root WebSocket endpoint (gateway handles all paths)
        let url = URL(string: "ws://127.0.0.1:\(effectivePort)")!
        return (url, effectiveToken, effectivePassword)
    }

    /// Parse `~/.openclaw/openclaw.json` for `gateway.port` and `gateway.auth.token`.
    private static func readOpenClawConfig() -> (port: Int?, token: String?) {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/openclaw.json")
        guard let data = try? Data(contentsOf: configURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gateway = root["gateway"] as? [String: Any]
        else { return (nil, nil) }

        let port = gateway["port"] as? Int
        let token = (gateway["auth"] as? [String: Any])?["token"] as? String
        return (port, token)
    }
}
