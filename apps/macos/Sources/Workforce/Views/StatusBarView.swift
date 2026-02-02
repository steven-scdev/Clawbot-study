import SwiftUI

struct StatusBarView: View {
    let state: WorkforceGatewayService.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            StatusDotView(
                color: self.dotColor,
                size: 6,
                isPulsing: self.state == .connecting)

            Text(self.label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var label: String {
        switch self.state {
        case .disconnected:
            "Disconnected"
        case .connecting:
            "Connecting..."
        case let .connected(version):
            "Connected to Gateway v\(version)"
        case let .error(message):
            "Error: \(message)"
        }
    }

    private var dotColor: Color {
        switch self.state {
        case .connected: .green
        case .connecting: .yellow
        case .error: .red
        case .disconnected: .secondary
        }
    }
}
