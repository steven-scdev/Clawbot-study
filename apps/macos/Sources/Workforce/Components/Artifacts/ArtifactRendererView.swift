import SwiftUI

/// Determines which rendering surface to use for a given output
enum ArtifactType {
    case web    // URL-based content → WKWebView
    case file   // File on disk → QLPreviewView
}

/// Routes a TaskOutput to the correct rendering surface
struct ArtifactRendererView: View {
    let output: TaskOutput
    var taskService: TaskService
    let taskId: String

    var body: some View {
        Group {
            switch classifyArtifact(output) {
            case .web:
                WebArtifactView(
                    url: output.url ?? "",
                    title: output.title
                )
            case .file:
                FileArtifactView(
                    filePath: output.filePath ?? "",
                    title: output.title,
                    outputType: output.type,
                    taskService: taskService,
                    taskId: taskId,
                    outputId: output.id
                )
            }
        }
    }

    /// Classify the output to determine the rendering surface
    /// URL present → web (WKWebView). File path present → file (QLPreviewView)
    private func classifyArtifact(_ output: TaskOutput) -> ArtifactType {
        if let url = output.url, url.hasPrefix("http") {
            return .web
        }
        return .file
    }
}
