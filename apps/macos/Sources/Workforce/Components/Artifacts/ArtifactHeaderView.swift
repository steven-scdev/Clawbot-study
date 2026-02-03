import SwiftUI

/// Header for artifact pane showing output selector and close button
struct ArtifactHeaderView: View {
    let currentOutput: TaskOutput?
    let allOutputs: [TaskOutput]
    let onOutputSelect: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Output type icon
            if let output = currentOutput {
                Image(systemName: output.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Output picker (only shown when multiple outputs exist)
            if allOutputs.count > 1 {
                outputPicker
            } else if let output = currentOutput {
                // Single output - just show the title
                Text(output.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            Spacer()

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close artifact preview")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.98))
    }

    private var outputPicker: some View {
        Picker("", selection: Binding(
            get: { currentOutput?.id ?? "" },
            set: { newId in
                onOutputSelect(newId)
            }
        )) {
            ForEach(allOutputs, id: \.id) { output in
                HStack {
                    Image(systemName: output.type.icon)
                    Text(output.title)
                }
                .tag(output.id)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
