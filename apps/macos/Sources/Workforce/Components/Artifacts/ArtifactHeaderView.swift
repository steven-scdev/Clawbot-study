import SwiftUI

/// Browser-chrome–style header for the artifact pane: muted dots, glass URL pill, Expand + close buttons.
struct ArtifactHeaderView: View {
    let currentOutput: TaskOutput?
    let allOutputs: [TaskOutput]
    let onOutputSelect: (String) -> Void
    let onClose: () -> Void
    var onExpand: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Decorative traffic-light dots (muted)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(white: 0.55).opacity(0.4))
                        .frame(width: 10, height: 10)
                }
            }
            .accessibilityHidden(true)
            .padding(.leading, 4)

            Spacer()

            // Glass URL pill
            urlPill

            Spacer()

            // Expand button
            if let onExpand {
                Button(action: onExpand) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Expand")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open in external app")
            }

            // Close button
            Button(action: self.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close artifact preview")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.4))
        .background(.ultraThinMaterial)
    }

    // MARK: - URL Pill

    private var displayText: String {
        guard let output = self.currentOutput else { return "No output" }
        if let url = output.url, let host = URL(string: url)?.host {
            return host
        }
        if let path = output.filePath {
            return (path as NSString).lastPathComponent
        }
        return output.title
    }

    @ViewBuilder
    private var urlPill: some View {
        if self.allOutputs.count > 1 {
            Menu {
                ForEach(self.allOutputs, id: \.id) { output in
                    Button {
                        self.onOutputSelect(output.id)
                    } label: {
                        Label(output.title, systemImage: output.type.icon)
                    }
                }
            } label: {
                pillContent(showChevron: true)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Switch output: \(self.displayText)")
        } else {
            pillContent(showChevron: false)
        }
    }

    private func pillContent(showChevron: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Text(self.displayText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }
}
