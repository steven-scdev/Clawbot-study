import Testing

@testable import Workforce

@Suite("SidebarItem")
struct SidebarItemTests {
    @Test("all cases present")
    func allCases() {
        #expect(SidebarItem.allCases.count == 4)
        #expect(SidebarItem.allCases.contains(.dashboard))
        #expect(SidebarItem.allCases.contains(.employees))
        #expect(SidebarItem.allCases.contains(.tasks))
        #expect(SidebarItem.allCases.contains(.memoryBank))
    }

    @Test("labels are human-readable")
    func labels() {
        #expect(SidebarItem.dashboard.label == "Dashboard")
        #expect(SidebarItem.employees.label == "Employees")
        #expect(SidebarItem.tasks.label == "Tasks")
        #expect(SidebarItem.memoryBank.label == "Memory Bank")
    }

    @Test("icons are valid SF Symbols names")
    func icons() {
        #expect(SidebarItem.dashboard.icon == "square.grid.2x2")
        #expect(SidebarItem.employees.icon == "person.3")
        #expect(SidebarItem.tasks.icon == "list.bullet.clipboard")
        #expect(SidebarItem.memoryBank.icon == "brain.head.profile")
    }

    @Test("identifiable produces unique IDs")
    func identifiable() {
        let ids = SidebarItem.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
