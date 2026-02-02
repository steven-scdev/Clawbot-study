import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard
    case employees
    case tasks
    case memoryBank

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .employees: "Employees"
        case .tasks: "Tasks"
        case .memoryBank: "Memory Bank"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .employees: "person.3"
        case .tasks: "list.bullet.clipboard"
        case .memoryBank: "brain.head.profile"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        VStack(spacing: 0) {
            // App branding — extra top padding for traffic light buttons
            self.header
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 12)

            // Navigation items
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarNavButton(
                        icon: item.icon,
                        label: item.label,
                        isSelected: self.selection == item
                    ) {
                        self.selection = item
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // User profile at bottom
            Divider()
                .overlay(Color.white.opacity(0.4))
                .padding(.horizontal, 12)

            SidebarUserProfile()
                .padding(12)
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        .background(Color.white.opacity(0.15))
    }

    private var header: some View {
        HStack(spacing: 10) {
            // App icon
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)

            Text("Workforce")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}
