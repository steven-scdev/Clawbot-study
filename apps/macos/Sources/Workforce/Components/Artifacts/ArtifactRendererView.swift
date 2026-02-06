import SwiftUI

/// Determines which rendering surface to use for a given output
enum ArtifactType {
    case web              // URL-based content -> WKWebView
    case file             // File on disk -> QLPreviewView
    case embeddedBrowser  // CDP screencast stream -> BrowserStreamView
}

/// Routes a TaskOutput to the correct rendering surface
struct ArtifactRendererView: View {
    let output: TaskOutput
    let isTaskRunning: Bool
    var taskService: TaskService
    let taskId: String

    var body: some View {
        let artifactType = self.classifyArtifact(self.output)
        let _ = print("[ArtifactRendererView] Rendering output: id=\(self.output.id), type=\(self.output.type), artifactType=\(artifactType)")
        Group {
            switch artifactType {
            case .web:
                WebArtifactView(
                    url: self.webURL(for: self.output),
                    title: self.output.title,
                    isTaskRunning: self.isTaskRunning,
                    taskId: self.taskId
                )
            case .file:
                FileArtifactView(
                    filePath: self.output.filePath ?? "",
                    title: self.output.title,
                    outputType: self.output.type,
                    isTaskRunning: self.isTaskRunning,
                    taskService: self.taskService,
                    taskId: self.taskId,
                    outputId: self.output.id
                )
            case .embeddedBrowser:
                BrowserStreamView(
                    taskId: self.taskId,
                    url: self.output.url ?? "",
                    taskService: self.taskService
                )
            }
        }
    }

    /// Classify artifact: embedded browser (CDP stream), web (WKWebView), or file (QLPreviewView).
    private func classifyArtifact(_ output: TaskOutput) -> ArtifactType {
        // Embedded browser output -> CDP screencast stream
        if output.type == .embeddedBrowser {
            return .embeddedBrowser
        }
        // URL present -> web (WKWebView)
        if let url = output.url, url.hasPrefix("http") {
            return .web
        }
        // HTML file path -> web (file:// URL)
        if let path = output.filePath, self.isHTMLFile(path) {
            return .web
        }
        // Other files -> QLPreviewView
        return .file
    }

    private func isHTMLFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "html" || ext == "htm"
    }

    private func webURL(for output: TaskOutput) -> String {
        if let url = output.url, url.hasPrefix("http") {
            return url
        }
        if let path = output.filePath {
            return URL(fileURLWithPath: path).absoluteString
        }
        return ""
    }
}
