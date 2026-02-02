import SwiftUI

/// Compact status indicator shown in the toolbar.
struct ConnectionStatusView: View {
    let state: WorkforceGatewayService.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(self.dotColor)
                .frame(width: 8, height: 8)
            Text(self.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var dotColor: Color {
        switch self.state {
        case .disconnected: .gray
        case .connecting: .orange
        case .connected: .green
        case .error: .red
        }
    }

    private var label: String {
        switch self.state {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case let .connected(version): "v\(version)"
        case let .error(message): message
        }
    }
}
