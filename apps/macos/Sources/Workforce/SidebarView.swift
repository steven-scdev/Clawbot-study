import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case employees
    case tasks
    case settings

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .employees: "Employees"
        case .tasks: "Tasks"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .employees: "person.3"
        case .tasks: "list.bullet.clipboard"
        case .settings: "gear"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(SidebarItem.allCases, selection: self.$selection) { item in
            Label(item.label, systemImage: item.icon)
                .tag(item)
        }
        .navigationTitle("Workforce")
        .listStyle(.sidebar)
    }
}
