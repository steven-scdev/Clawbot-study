import SwiftUI

/// Full-screen placeholder shown when the gateway is not connected.
struct GatewayNotRunningView: View {
    let state: WorkforceGatewayService.ConnectionState
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text(self.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(self.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if case .connecting = self.state {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Retry Connection") {
                    self.onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch self.state {
        case .disconnected: "Gateway Not Running"
        case .connecting: "Connecting to Gateway…"
        case .error: "Connection Error"
        case .connected: "Connected"
        }
    }

    private var subtitle: String {
        switch self.state {
        case .disconnected:
            "Start the OpenClaw gateway to use Workforce. The app will connect automatically."
        case .connecting:
            "Establishing connection to the gateway…"
        case let .error(message):
            message
        case .connected:
            ""
        }
    }
}
