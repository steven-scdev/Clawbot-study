import SwiftUI

struct EmployeeCardView: View {
    let employee: Employee
    var onAssign: (() -> Void)?

    @State private var isHovered = false

    private var isOnline: Bool {
        self.employee.status == .online
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top row: status badge + memory icon
            HStack {
                StatusBadgeView(status: self.employee.status)
                Spacer()
                self.memoryIcon
            }
            .padding(.bottom, 12)

            // Avatar
            self.avatarView
                .padding(.bottom, 10)

            // Name + title
            Text(self.employee.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .padding(.bottom, 2)

            Text(self.employee.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(self.isOnline ? Color.accentColor : Color(white: 0.45))
                .padding(.bottom, 14)

            // Capabilities
            VStack(alignment: .leading, spacing: 8) {
                ForEach(self.employee.displayCapabilities, id: \.self) { capability in
                    HStack(spacing: 8) {
                        Image(systemName: self.capabilityIcon(for: capability))
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.45))
                            .frame(width: 16)
                        Text(capability)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(self.isOnline || self.isHovered ? 1 : 0.7)
            .padding(.bottom, 8)

            // Skills
            if !self.employee.displaySkills.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))
                    ForEach(self.employee.displaySkills, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(white: 0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(self.isOnline || self.isHovered ? 1 : 0.6)
            }

            Spacer(minLength: 0)

            // Action button
            self.actionButton
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(
            cornerRadius: 16,
            isHovered: self.isHovered,
            isActive: self.isOnline
        )
        .glowBorder(
            isActive: self.isOnline && self.isHovered,
            cornerRadius: 16
        )
        .shimmer(isActive: self.isOnline)
        .scaleEffect(self.isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: self.isHovered)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }

    // MARK: - Subviews

    private var memoryIcon: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 13))
            .foregroundStyle(self.isOnline ? Color.accentColor : Color(white: 0.5))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color.white.opacity(self.isOnline ? 0.5 : 0.3))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
    }

    private var avatarView: some View {
        ZStack {
            if self.isOnline {
                Circle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: 76, height: 76)
                    .blur(radius: 10)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: self.isOnline
                            ? [.blue.opacity(0.3), .purple.opacity(0.2)]
                            : [.gray.opacity(0.2), .gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: self.employee.avatarSystemName)
                        .font(.system(size: 30))
                        .foregroundStyle(self.isOnline ? Color.accentColor : .secondary)
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.white.opacity(self.isOnline ? 0.4 : 0.2),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: self.isOnline ? .blue.opacity(0.2) : .clear,
                    radius: 8
                )
                .saturation(self.isOnline || self.isHovered ? 1 : 0.7)
        }
    }

    private var actionButton: some View {
        Button {
            self.onAssign?()
        } label: {
            HStack(spacing: 6) {
                Text(self.buttonLabel)
                    .font(.system(size: 13, weight: .medium))
                if self.isOnline {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(self.buttonBackground)
            .foregroundStyle(self.buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(self.employee.status == .busy)
        .opacity(self.employee.status == .busy ? 0.5 : 1)
    }

    private var buttonLabel: String {
        switch self.employee.status {
        case .online: "Assign Task"
        case .busy: "In Progress"
        case .idle, .offline, .unknown: "View Profile"
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if self.isOnline {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor)
                .shadow(color: .blue.opacity(0.3), radius: 6, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
        }
    }

    private var buttonForeground: Color {
        self.isOnline ? .white : Color(white: 0.2)
    }

    // MARK: - Helpers

    private func capabilityIcon(for capability: String) -> String {
        let lower = capability.lowercased()
        if lower.contains("trend") || lower.contains("graph") { return "chart.line.uptrend.xyaxis" }
        if lower.contains("copy") || lower.contains("writ") { return "pencil.line" }
        if lower.contains("web") || lower.contains("react") { return "globe" }
        if lower.contains("data") || lower.contains("viz") { return "chart.bar" }
        if lower.contains("model") || lower.contains("complex") { return "function" }
        if lower.contains("present") { return "rectangle.on.rectangle" }
        if lower.contains("full stack") || lower.contains("dev") { return "chevron.left.forwardslash.chevron.right" }
        if lower.contains("system") || lower.contains("design") { return "cpu" }
        if lower.contains("research") { return "magnifyingglass" }
        return "circle.fill"
    }
}
