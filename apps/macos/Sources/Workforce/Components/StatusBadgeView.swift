import SwiftUI

struct StatusBadgeView: View {
    let status: EmployeeStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(self.dotColor)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .fill(self.dotColor)
                        .frame(width: 6, height: 6)
                        .scaleEffect(self.status == .online ? 1.8 : 1)
                        .opacity(self.status == .online ? 0 : 1)
                        .animation(
                            self.status == .online
                                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: false)
                                : .default,
                            value: self.status
                        )
                )

            Text(self.label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(self.backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(self.borderColor, lineWidth: 0.5)
        )
    }

    private var label: String {
        switch self.status {
        case .online: "ONLINE"
        case .idle: "IDLE"
        case .busy: "BUSY"
        case .offline: "OFFLINE"
        case .unknown: "UNKNOWN"
        }
    }

    private var dotColor: Color {
        switch self.status {
        case .online: .green
        case .idle: .gray
        case .busy: .yellow
        case .offline, .unknown: .gray
        }
    }

    private var backgroundColor: Color {
        switch self.status {
        case .online: .green.opacity(0.15)
        case .idle: .gray.opacity(0.15)
        case .busy: .yellow.opacity(0.15)
        case .offline, .unknown: .gray.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch self.status {
        case .online: .green.opacity(0.3)
        case .idle: .gray.opacity(0.2)
        case .busy: .yellow.opacity(0.3)
        case .offline, .unknown: .gray.opacity(0.15)
        }
    }
}
