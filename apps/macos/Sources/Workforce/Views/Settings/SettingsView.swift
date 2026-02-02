import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case gateway
    case folders

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .gateway: "Gateway"
        case .folders: "Folders"
        }
    }

    var icon: String {
        switch self {
        case .gateway: "network"
        case .folders: "folder"
        }
    }
}

struct SettingsView: View {
    var gatewayService: WorkforceGatewayService
    @State private var selectedTab: SettingsTab = .gateway

    var body: some View {
        TabView(selection: self.$selectedTab) {
            Tab(SettingsTab.gateway.label, systemImage: SettingsTab.gateway.icon, value: .gateway) {
                GatewaySettingsView(gatewayService: self.gatewayService)
            }

            Tab(SettingsTab.folders.label, systemImage: SettingsTab.folders.icon, value: .folders) {
                FoldersSettingsView()
            }
        }
        .frame(width: 500, height: 400)
    }
}
