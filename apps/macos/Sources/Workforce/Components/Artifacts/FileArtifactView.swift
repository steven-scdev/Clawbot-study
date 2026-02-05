import SwiftUI
import Quartz
import AppKit

/// Bare QLPreviewView wrapper for displaying file-based artifacts.
/// File header chrome is now provided by ArtifactHeaderView at the pane level.
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

    var body: some View {
        Group {
            if self.fileExists {
                QuickLookPreviewView(filePath: self.filePath, refreshToken: self.refreshToken)
            } else {
                placeholderView
            }
        }
        .onAppear {
            self.checkFileExists()
            self.startPollingIfNeeded()
        }
        .onDisappear {
            self.stopPolling()
        }
        .onChange(of: self.filePath) {
            self.checkFileExists()
            self.startPollingIfNeeded()
        }
        .onChange(of: self.isTaskRunning) {
            if !self.isTaskRunning {
                // One-shot refresh when task completes to show final content
                self.refreshToken &+= 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .artifactRefreshRequested)) { notification in
            guard let userInfo = notification.userInfo,
                  let notifTaskId = userInfo["taskId"] as? String,
                  notifTaskId == self.taskId else { return }
            self.refreshToken &+= 1
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Generating...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(self.filePath)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkFileExists() {
        self.fileExists = FileManager.default.fileExists(atPath: self.filePath)
    }

    private func startPollingIfNeeded() {
        self.stopPolling()
        guard !self.fileExists else { return }
        self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkFileExists()
                if self.fileExists { self.stopPolling() }
            }
        }
    }

    private func stopPolling() {
        self.pollTimer?.invalidate()
        self.pollTimer = nil
    }

    func revealInFinder() {
        guard self.fileExists else { return }
        NSWorkspace.shared.selectFile(self.filePath, inFileViewerRootedAtPath: "")
    }

    func openInDefaultApp() {
        guard self.fileExists else { return }
        let url = URL(fileURLWithPath: self.filePath)
        NSWorkspace.shared.open(url)
    }
}

/// NSViewRepresentable wrapper for QLPreviewView with live refresh support.
/// Uses a Coordinator to track previous state and avoid unnecessary reloads
/// that reset the scroll position.
struct QuickLookPreviewView: NSViewRepresentable {
    let filePath: String
    var refreshToken: UInt64 = 0

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView()
        previewView.autostarts = true
        let url = URL(fileURLWithPath: self.filePath)
        previewView.previewItem = url as QLPreviewItem
        context.coordinator.lastFilePath = self.filePath
        context.coordinator.lastRefreshToken = self.refreshToken
        return previewView
    }

    func updateNSView(_ previewView: QLPreviewView, context: Context) {
        let coordinator = context.coordinator

        if self.filePath != coordinator.lastFilePath {
            // File changed — load the new item
            let url = URL(fileURLWithPath: self.filePath)
            previewView.previewItem = url as QLPreviewItem
            coordinator.lastFilePath = self.filePath
            coordinator.lastRefreshToken = self.refreshToken
        } else if self.refreshToken != coordinator.lastRefreshToken {
            // Same file, explicit refresh requested (e.g. task finished generating)
            previewView.refreshPreviewItem()
            coordinator.lastRefreshToken = self.refreshToken
        }
        // Otherwise: no-op — preserves scroll position
    }

    class Coordinator {
        var lastFilePath: String = ""
        var lastRefreshToken: UInt64 = 0
    }
}
