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
    @State private var refreshTimer: Timer?

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
            if self.isTaskRunning { self.startRefreshTimer() }
        }
        .onDisappear {
            self.stopPolling()
            self.stopRefreshTimer()
        }
        .onChange(of: self.filePath) {
            self.checkFileExists()
            self.startPollingIfNeeded()
        }
        .onChange(of: self.isTaskRunning) {
            if self.isTaskRunning {
                self.startRefreshTimer()
            } else {
                self.stopRefreshTimer()
                self.refreshToken &+= 1
            }
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

    private func startRefreshTimer() {
        self.stopRefreshTimer()
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                self.refreshToken &+= 1
            }
        }
    }

    private func stopRefreshTimer() {
        self.refreshTimer?.invalidate()
        self.refreshTimer = nil
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
        let url = URL(fileURLWithPath: self.filePath)
        previewView.previewItem = url as QLPreviewItem
        previewView.refreshPreviewItem()
    }
}
