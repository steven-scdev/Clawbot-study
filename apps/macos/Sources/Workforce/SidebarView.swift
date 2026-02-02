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
    @Binding var isCollapsed: Bool

    private var sidebarWidth: CGFloat {
        self.isCollapsed ? 56 : 220
    }

    var body: some View {
        VStack(spacing: 0) {
            // App branding — tap to toggle sidebar
            self.header
                .padding(.horizontal, self.isCollapsed ? 0 : 16)
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.isCollapsed.toggle()
                    }
                }

            // Navigation items
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarNavButton(
                        icon: item.icon,
                        label: item.label,
                        isSelected: self.selection == item,
                        isCollapsed: self.isCollapsed
                    ) {
                        self.selection = item
                    }
                }
            }
            .padding(.horizontal, self.isCollapsed ? 8 : 12)

            Spacer()

            // User profile at bottom
            if !self.isCollapsed {
                Divider()
                    .overlay(Color.white.opacity(0.4))
                    .padding(.horizontal, 12)
            }

            SidebarUserProfile(isCollapsed: self.isCollapsed)
                .padding(self.isCollapsed ? 8 : 12)
        }
        .frame(width: self.sidebarWidth)
        .background(Color.white.opacity(0.15))
        .clipped()
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
                    Text("W")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)

            if !self.isCollapsed {
                Text("Workforce")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(white: 0.2))
            }
        }
    }
}
