import Testing

@testable import Workforce

@Suite("SidebarItem")
struct SidebarItemTests {
    @Test("all cases present")
    func allCases() {
        #expect(SidebarItem.allCases.count == 3)
        #expect(SidebarItem.allCases.contains(.employees))
        #expect(SidebarItem.allCases.contains(.tasks))
        #expect(SidebarItem.allCases.contains(.settings))
    }

    @Test("labels are human-readable")
    func labels() {
        #expect(SidebarItem.employees.label == "Employees")
        #expect(SidebarItem.tasks.label == "Tasks")
        #expect(SidebarItem.settings.label == "Settings")
    }

    @Test("icons are valid SF Symbols names")
    func icons() {
        #expect(SidebarItem.employees.icon == "person.3")
        #expect(SidebarItem.tasks.icon == "list.bullet.clipboard")
        #expect(SidebarItem.settings.icon == "gear")
    }

    @Test("identifiable produces unique IDs")
    func identifiable() {
        let ids = SidebarItem.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
