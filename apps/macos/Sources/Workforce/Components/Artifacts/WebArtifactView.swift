import SwiftUI
import WebKit

/// Bare WKWebView wrapper for displaying web-based artifacts.
/// Browser chrome is now provided by ArtifactHeaderView at the pane level.
struct WebArtifactView: View {
    let url: String
    let title: String
    var isTaskRunning: Bool = false
    var taskId: String = ""

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewCoordinator: WebViewCoordinator?
    @State private var refreshTimer: Timer?

    /// Whether this is a local file URL (vs web URL).
    /// Only local files get auto-refreshed; web URLs are controlled by the agent.
    private var isLocalFileURL: Bool {
        URL(string: self.url)?.isFileURL ?? false
    }

    var body: some View {
        ZStack {
            WebViewRepresentable(
                url: self.url,
                taskId: self.taskId,
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
                // Only auto-refresh local files, not web URLs
                if self.isLocalFileURL {
                    self.startRefreshTimer()
                }
            } else {
                self.stopRefreshTimer()
                // Only auto-reload local files when task completes
                if self.isLocalFileURL {
                    self.webViewCoordinator?.reload()
                }
            }
        }
        .onAppear {
            // Only auto-refresh local files, not web URLs
            if self.isTaskRunning && self.isLocalFileURL {
                self.startRefreshTimer()
            }
        }
        .onDisappear {
            self.stopRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .artifactRefreshRequested)) { notification in
            guard let userInfo = notification.userInfo,
                  let notifTaskId = userInfo["taskId"] as? String,
                  notifTaskId == self.taskId else { return }
            self.webViewCoordinator?.reload()
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
    let taskId: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var coordinator: WebViewCoordinator?

    func makeNSView(context: Context) -> WKWebView {
        // Configure WKWebView with proper settings for web compatibility
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Use a non-persistent data store to avoid cookie issues between sessions
        // Comment out if you want persistent login sessions:
        // configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Set a Safari-like user agent to avoid site blocking
        // This mimics Safari 17 on macOS Sonoma
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // Allow developer extras for debugging (optional)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        // Set both navigation and UI delegates
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.taskId = self.taskId
        DispatchQueue.main.async {
            self.coordinator = context.coordinator
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update taskId in case it changed
        context.coordinator.taskId = self.taskId

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

/// Coordinator for WKWebView navigation delegate with browser control capabilities.
/// Handles agent-invoked JavaScript execution, state observation, and navigation.
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    weak var webView: WKWebView?

    /// Task ID for filtering browser control notifications
    var taskId: String?

    /// Pending navigation requests waiting for didFinish callback
    private var pendingNavigationRequestId: String?

    /// Track if agent is actively controlling the browser (suppresses auto-refresh errors)
    var isAgentControlled: Bool = false

    init(isLoading: Binding<Bool>, loadError: Binding<String?>, canGoBack: Binding<Bool>, canGoForward: Binding<Bool>) {
        self._isLoading = isLoading
        self._loadError = loadError
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        super.init()
        self.setupBrowserControlObservers()
    }

    deinit {
        // Remove observers directly in deinit (safe because NotificationCenter handles thread safety)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Browser Control Observers

    private func setupBrowserControlObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExecuteRequest),
            name: .browserExecuteRequest,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleObserveRequest),
            name: .browserObserveRequest,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateRequest),
            name: .browserNavigateRequest,
            object: nil
        )
    }

    private func removeBrowserControlObservers() {
        NotificationCenter.default.removeObserver(self, name: .browserExecuteRequest, object: nil)
        NotificationCenter.default.removeObserver(self, name: .browserObserveRequest, object: nil)
        NotificationCenter.default.removeObserver(self, name: .browserNavigateRequest, object: nil)
    }

    // MARK: - Browser Control Handlers

    @objc private func handleExecuteRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notifTaskId = userInfo["taskId"] as? String,
              let requestId = userInfo["requestId"] as? String,
              let script = userInfo["script"] as? String,
              notifTaskId == self.taskId,
              let webView = self.webView else { return }

        webView.evaluateJavaScript(script) { result, error in
            Task { @MainActor in
                if let error = error {
                    await TaskService.shared.sendBrowserResponse(
                        requestId: requestId,
                        success: false,
                        error: error.localizedDescription
                    )
                } else {
                    await TaskService.shared.sendBrowserResponse(
                        requestId: requestId,
                        success: true,
                        result: result
                    )
                }
            }
        }
    }

    @objc private func handleObserveRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notifTaskId = userInfo["taskId"] as? String,
              let requestId = userInfo["requestId"] as? String,
              notifTaskId == self.taskId,
              let webView = self.webView else { return }

        // Capture DOM, screenshot, URL, and title
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak webView] dom, domError in
            guard let webView = webView else {
                Task { @MainActor in
                    await TaskService.shared.sendBrowserResponse(
                        requestId: requestId,
                        success: false,
                        error: "WebView no longer available"
                    )
                }
                return
            }

            // Take screenshot
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, snapshotError in
                Task { @MainActor in
                    if let error = domError ?? snapshotError {
                        await TaskService.shared.sendBrowserResponse(
                            requestId: requestId,
                            success: false,
                            error: error.localizedDescription
                        )
                        return
                    }

                    // Convert screenshot to base64 PNG
                    var screenshotBase64: String?
                    if let image = image,
                       let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        screenshotBase64 = pngData.base64EncodedString()
                    }

                    let result: [String: Any] = [
                        "dom": dom as? String ?? "",
                        "screenshot": screenshotBase64 ?? "",
                        "url": webView.url?.absoluteString ?? "",
                        "title": webView.title ?? ""
                    ]

                    await TaskService.shared.sendBrowserResponse(
                        requestId: requestId,
                        success: true,
                        result: result
                    )
                }
            }
        }
    }

    @objc private func handleNavigateRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notifTaskId = userInfo["taskId"] as? String,
              let requestId = userInfo["requestId"] as? String,
              let urlString = userInfo["url"] as? String,
              notifTaskId == self.taskId,
              let webView = self.webView else { return }

        guard let url = URL(string: urlString) else {
            Task { @MainActor in
                await TaskService.shared.sendBrowserResponse(
                    requestId: requestId,
                    success: false,
                    error: "Invalid URL: \(urlString)"
                )
            }
            return
        }

        // Store pending request ID to resolve when navigation completes
        self.pendingNavigationRequestId = requestId
        self.isAgentControlled = true

        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.isLoading = true
        self.loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isLoading = false
        self.loadError = nil  // Clear any previous error on successful load
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward

        // Resolve pending navigation request
        if let requestId = self.pendingNavigationRequestId {
            self.pendingNavigationRequestId = nil
            self.isAgentControlled = false
            Task { @MainActor in
                await TaskService.shared.sendBrowserResponse(
                    requestId: requestId,
                    success: true,
                    result: ["url": webView.url?.absoluteString ?? "", "title": webView.title ?? ""]
                )
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false

        // Don't show error overlay for cancelled navigations (e.g., from refresh timer)
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            self.loadError = error.localizedDescription
        }

        // Resolve pending navigation request with error
        if let requestId = self.pendingNavigationRequestId {
            self.pendingNavigationRequestId = nil
            self.isAgentControlled = false
            Task { @MainActor in
                await TaskService.shared.sendBrowserResponse(
                    requestId: requestId,
                    success: false,
                    error: error.localizedDescription
                )
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.isLoading = false

        // Don't show error overlay for cancelled navigations (e.g., from refresh timer)
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled {
            self.loadError = error.localizedDescription
        }

        // Resolve pending navigation request with error
        if let requestId = self.pendingNavigationRequestId {
            self.pendingNavigationRequestId = nil
            self.isAgentControlled = false
            Task { @MainActor in
                await TaskService.shared.sendBrowserResponse(
                    requestId: requestId,
                    success: false,
                    error: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Navigation Controls

    func goBack() {
        self.webView?.goBack()
    }

    func goForward() {
        self.webView?.goForward()
    }

    func reload() {
        // Skip auto-refresh when agent is actively controlling the browser
        if self.isAgentControlled {
            return
        }

        if self.isLoading {
            self.webView?.stopLoading()
            self.isLoading = false
        } else {
            self.webView?.reload()
        }
    }

    // MARK: - WKUIDelegate

    /// Handle JavaScript alert() calls
    @MainActor
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable () -> Void
    ) {
        // For now, just acknowledge the alert without showing UI
        // In the future, could show a native alert or send to agent
        completionHandler()
    }

    /// Handle JavaScript confirm() calls
    @MainActor
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        // Default to confirming (true) for automated workflows
        completionHandler(true)
    }

    /// Handle JavaScript prompt() calls
    @MainActor
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        // Return default text or empty string
        completionHandler(defaultText ?? "")
    }

    /// Handle window.open() - load in same WebView instead of opening new window
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Load the URL in the current WebView instead of opening a new window
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
