import SwiftUI

struct GatewaySettingsView: View {
    var gatewayService: WorkforceGatewayService

    @AppStorage("workforceGatewayPort") private var port = 18789
    @AppStorage("workforceGatewayToken") private var token = ""

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
            }

            Section {
                Button("Reconnect") {
                    Task { await self.gatewayService.connect() }
                }
                .disabled(self.gatewayService.connectionState == .connecting)
            }
        }
        .formStyle(.grouped)
    }
}
