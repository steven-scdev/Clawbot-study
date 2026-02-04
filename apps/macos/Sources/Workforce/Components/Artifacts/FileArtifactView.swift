import SwiftUI
import Quartz
import AppKit

/// QLPreviewView wrapper for displaying file-based artifacts with header controls
struct FileArtifactView: View {
    let filePath: String
    let title: String
    let outputType: OutputType
    var isTaskRunning: Bool = false
    var taskService: TaskService
    let taskId: String
    let outputId: String

    @State private var fileExists = false
    @State private var pollTimer: Timer?
    @State private var refreshToken: UInt64 = 0
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // File header with icon, title, and action buttons
            fileHeader

            Divider()

            // Preview content or placeholder
            if fileExists {
                QuickLookPreviewView(filePath: filePath, refreshToken: refreshToken)
            } else {
                placeholderView
            }
        }
        .onAppear {
            checkFileExists()
            startPollingIfNeeded()
            if isTaskRunning { startRefreshTimer() }
        }
        .onDisappear {
            stopPolling()
            stopRefreshTimer()
        }
        .onChange(of: filePath) {
            checkFileExists()
            startPollingIfNeeded()
        }
        .onChange(of: isTaskRunning) {
            if isTaskRunning {
                startRefreshTimer()
            } else {
                stopRefreshTimer()
                // One final refresh to show completed state
                refreshToken &+= 1
            }
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
        let exists = FileManager.default.fileExists(atPath: filePath)
        print("[FileArtifactView] checkFileExists path=\(filePath) exists=\(exists)")
        fileExists = exists
    }

    private func startPollingIfNeeded() {
        stopPolling()
        guard !fileExists else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                checkFileExists()
                if fileExists { stopPolling() }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                refreshToken &+= 1
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
    var refreshToken: UInt64 = 0

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
