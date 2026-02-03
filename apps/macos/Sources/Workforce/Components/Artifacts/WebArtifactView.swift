import SwiftUI
import WebKit

/// WKWebView wrapper for displaying web-based artifacts with browser chrome
struct WebArtifactView: View {
    let url: String
    let title: String

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewCoordinator: WebViewCoordinator?

    var body: some View {
        VStack(spacing: 0) {
            // Browser chrome toolbar
            browserChrome

            Divider()

            // WebView container
            WebViewRepresentable(
                url: url,
                isLoading: $isLoading,
                loadError: $loadError,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                coordinator: $webViewCoordinator
            )

            // Error overlay
            if let error = loadError {
                errorOverlay(error)
            }
        }
    }

    private var browserChrome: some View {
        HStack(spacing: 12) {
            Button {
                webViewCoordinator?.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)

            Button {
                webViewCoordinator?.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)

            Button {
                webViewCoordinator?.reload()
            } label: {
                Image(systemName: isLoading ? "stop.fill" : "arrow.clockwise")
            }

            Text(url)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(white: 0.98))
    }

    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Failed to Load")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.97))
    }
}

/// NSViewRepresentable wrapper for WKWebView
struct WebViewRepresentable: NSViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var coordinator: WebViewCoordinator?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        DispatchQueue.main.async {
            self.coordinator = context.coordinator
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: url) else {
            loadError = "Invalid URL"
            return
        }
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(
            isLoading: $isLoading,
            loadError: $loadError,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward
        )
    }
}

/// Coordinator for WKWebView navigation delegate
class WebViewCoordinator: NSObject, WKNavigationDelegate {
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    weak var webView: WKWebView?

    init(isLoading: Binding<Bool>, loadError: Binding<String?>, canGoBack: Binding<Bool>, canGoForward: Binding<Bool>) {
        _isLoading = isLoading
        _loadError = loadError
        _canGoBack = canGoBack
        _canGoForward = canGoForward
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        loadError = error.localizedDescription
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        if isLoading {
            webView?.stopLoading()
            isLoading = false
        } else {
            webView?.reload()
        }
    }
}
