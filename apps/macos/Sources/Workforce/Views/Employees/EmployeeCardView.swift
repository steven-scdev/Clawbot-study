import SwiftUI

struct EmployeeCardView: View {
    let employee: Employee
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            Text(self.employee.emoji)
                .font(.system(size: 40))

            VStack(spacing: 4) {
                Text(self.employee.name)
                    .font(.headline)
                Text(self.employee.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(self.statusColor)
                    .frame(width: 8, height: 8)
                Text(self.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(self.isHovered ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(self.isHovered ? 0.12 : 0.06), radius: self.isHovered ? 8 : 4)
        .scaleEffect(self.isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: self.isHovered)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }

    private var statusColor: Color {
        switch self.employee.status {
        case .online: .green
        case .busy: .yellow
        case .offline, .unknown: .gray
        }
    }

    private var statusLabel: String {
        switch self.employee.status {
        case .online: "Available"
        case .busy: "Busy"
        case .offline: "Offline"
        case .unknown: "Unknown"
        }
    }
}
