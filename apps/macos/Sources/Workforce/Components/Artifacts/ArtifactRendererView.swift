import SwiftUI

/// Determines which rendering surface to use for a given output
enum ArtifactType {
    case web    // URL-based content → WKWebView
    case file   // File on disk → QLPreviewView
}

/// Routes a TaskOutput to the correct rendering surface
struct ArtifactRendererView: View {
    let output: TaskOutput
    let isTaskRunning: Bool
    var taskService: TaskService
    let taskId: String

    var body: some View {
        Group {
            switch classifyArtifact(output) {
            case .web:
                WebArtifactView(
                    url: webURL(for: output),
                    title: output.title,
                    isTaskRunning: isTaskRunning
                )
            case .file:
                FileArtifactView(
                    filePath: output.filePath ?? "",
                    title: output.title,
                    outputType: output.type,
                    isTaskRunning: isTaskRunning,
                    taskService: taskService,
                    taskId: taskId,
                    outputId: output.id
                )
            }
        }
    }

    /// Classify the output to determine the rendering surface
    /// URL present → web (WKWebView). HTML file path → web (file:// URL). Other files → QLPreviewView
    private func classifyArtifact(_ output: TaskOutput) -> ArtifactType {
        if let url = output.url, url.hasPrefix("http") {
            return .web
        }
        // Route HTML files to WKWebView for proper rendering
        if let path = output.filePath, isHTMLFile(path) {
            return .web
        }
        return .file
    }

    private func isHTMLFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "html" || ext == "htm"
    }

    /// Build a display URL: use the output's URL if present, or convert file path to file:// URL
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
