import SwiftUI
import Quartz
import AppKit

/// QLPreviewView wrapper for displaying file-based artifacts with header controls
struct FileArtifactView: View {
    let filePath: String
    let title: String
    let outputType: OutputType
    var taskService: TaskService
    let taskId: String
    let outputId: String

    @State private var fileExists = false

    var body: some View {
        VStack(spacing: 0) {
            // File header with icon, title, and action buttons
            fileHeader

            Divider()

            // Preview content or placeholder
            if fileExists {
                QuickLookPreviewView(filePath: filePath)
            } else {
                placeholderView
            }
        }
        .onAppear {
            checkFileExists()
        }
    }

    private var fileHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: outputType.icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                revealInFinder()
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
            .disabled(!fileExists)

            Button {
                openInDefaultApp()
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Open")
            .disabled(!fileExists)
        }
        .padding(8)
        .background(Color(white: 0.98))
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Generating...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(filePath)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.97))
    }

    private func checkFileExists() {
        fileExists = FileManager.default.fileExists(atPath: filePath)
    }

    private func revealInFinder() {
        guard fileExists else { return }
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
    }

    private func openInDefaultApp() {
        guard fileExists else { return }
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }
}

/// NSViewRepresentable wrapper for QLPreviewView with live refresh support
struct QuickLookPreviewView: NSViewRepresentable {
    let filePath: String

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView()
        previewView.autostarts = true
        return previewView
    }

    func updateNSView(_ previewView: QLPreviewView, context: Context) {
        let url = URL(fileURLWithPath: filePath)

        // Set the preview item
        previewView.previewItem = url as QLPreviewItem

        // Refresh to show latest content (supports live updates during task execution)
        previewView.refreshPreviewItem()
    }
}
