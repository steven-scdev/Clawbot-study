import Foundation
import OpenClawKit
import OpenClawProtocol

typealias AnyCodable = OpenClawKit.AnyCodable

enum WorkforceGatewayError: Error, LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected: "Gateway not connected"
        }
    }
}

/// Low-level gateway actor that wraps `GatewayChannelActor` from OpenClawKit.
/// Handles WebSocket connection, RPC calls, and push event fan-out.
actor WorkforceGateway {
    typealias Config = (url: URL, token: String?, password: String?)

    private var client: GatewayChannelActor?
    private var subscribers: [UUID: AsyncStream<GatewayPush>.Continuation] = [:]
    private var lastSnapshot: HelloOk?
    private let decoder = JSONDecoder()

    func connect(url: URL, token: String?, password: String?) async throws {
        if let client {
            await client.shutdown()
        }
        let channel = GatewayChannelActor(
            url: url,
            token: token,
            password: password,
            pushHandler: { [weak self] push in
                await self?.handlePush(push)
            },
            disconnectHandler: { [weak self] reason in
                await self?.handleDisconnect(reason)
            })
        self.client = channel
        try await channel.connect()
    }

    func request(method: String, params: [String: AnyCodable]? = nil, timeoutMs: Double? = nil) async throws -> Data {
        guard let client else { throw WorkforceGatewayError.notConnected }
        return try await client.request(method: method, params: params, timeoutMs: timeoutMs)
    }

    func requestDecoded<T: Decodable>(method: String, params: [String: AnyCodable]? = nil) async throws -> T {
        let data = try await self.request(method: method, params: params)
        return try self.decoder.decode(T.self, from: data)
    }

    func subscribe(bufferingNewest: Int = 100) -> AsyncStream<GatewayPush> {
        let id = UUID()
        let snapshot = self.lastSnapshot
        return AsyncStream(bufferingPolicy: .bufferingNewest(bufferingNewest)) { continuation in
            if let snapshot {
                continuation.yield(.snapshot(snapshot))
            }
            self.subscribers[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeSubscriber(id) }
            }
        }
    }

    func shutdown() async {
        if let client {
            await client.shutdown()
        }
        self.client = nil
        self.lastSnapshot = nil
        for (_, c) in self.subscribers {
            c.finish()
        }
        self.subscribers.removeAll()
    }

    private func handlePush(_ push: GatewayPush) {
        if case let .snapshot(hello) = push {
            self.lastSnapshot = hello
        }
        for (_, c) in self.subscribers {
            c.yield(push)
        }
    }

    private func handleDisconnect(_ reason: String) {
        self.client = nil
        self.lastSnapshot = nil
        for (_, c) in self.subscribers {
            c.finish()
        }
        self.subscribers.removeAll()
    }

    private func removeSubscriber(_ id: UUID) {
        self.subscribers[id] = nil
    }
}
