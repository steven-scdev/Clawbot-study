import SwiftUI

struct GatewaySettingsView: View {
    var gatewayService: WorkforceGatewayService

    @AppStorage("workforceGatewayPort") private var port = 18789
    @AppStorage("workforceGatewayToken") private var token = ""
    @AppStorage("workforceGatewayPassword") private var password = ""

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    ConnectionStatusView(state: self.gatewayService.connectionState)
                }

                TextField("Port", value: self.$port, format: .number)
                    .textFieldStyle(.roundedBorder)

                SecureField("Token", text: self.$token)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password (optional)", text: self.$password)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button("Reconnect") {
                    Task { await self.gatewayService.connect() }
                }
                .disabled(self.gatewayService.connectionState == .connecting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
    }
}
