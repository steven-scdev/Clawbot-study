import SwiftUI
import WebKit

/// Bare WKWebView wrapper for displaying web-based artifacts.
/// Browser chrome is now provided by ArtifactHeaderView at the pane level.
struct WebArtifactView: View {
    let url: String
    let title: String
    var isTaskRunning: Bool = false

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewCoordinator: WebViewCoordinator?
    @State private var refreshTimer: Timer?

    var body: some View {
        ZStack {
            WebViewRepresentable(
                url: self.url,
                isLoading: self.$isLoading,
                loadError: self.$loadError,
                canGoBack: self.$canGoBack,
                canGoForward: self.$canGoForward,
                coordinator: self.$webViewCoordinator
            )

            if let error = self.loadError {
                errorOverlay(error)
            }

            if self.isLoading {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .onChange(of: self.isTaskRunning) {
            if self.isTaskRunning {
                self.startRefreshTimer()
            } else {
                self.stopRefreshTimer()
                self.webViewCoordinator?.reload()
            }
        }
        .onAppear {
            if self.isTaskRunning { self.startRefreshTimer() }
        }
        .onDisappear {
            self.stopRefreshTimer()
        }
    }

    private func startRefreshTimer() {
        self.stopRefreshTimer()
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                self.webViewCoordinator?.reload()
            }
        }
    }

    private func stopRefreshTimer() {
        self.refreshTimer?.invalidate()
        self.refreshTimer = nil
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
        guard let url = URL(string: self.url) else {
            self.loadError = "Invalid URL"
            return
        }
        if webView.url?.absoluteString != url.absoluteString {
            if url.isFileURL {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                webView.load(URLRequest(url: url))
            }
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(
            isLoading: self.$isLoading,
            loadError: self.$loadError,
            canGoBack: self.$canGoBack,
            canGoForward: self.$canGoForward
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
        self._isLoading = isLoading
        self._loadError = loadError
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.isLoading = true
        self.loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isLoading = false
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false
        self.loadError = error.localizedDescription
    }

    func goBack() {
        self.webView?.goBack()
    }

    func goForward() {
        self.webView?.goForward()
    }

    func reload() {
        if self.isLoading {
            self.webView?.stopLoading()
            self.isLoading = false
        } else {
            self.webView?.reload()
        }
    }
}
