import SwiftUI
import AppKit

/// View for displaying streamed browser frames from CDP Screencast.
/// Handles frame display and forwards mouse/keyboard input to the gateway.
struct BrowserStreamView: View {
    let taskId: String
    let url: String
    var taskService: TaskService

    @State private var currentFrame: NSImage?
    @State private var frameMetadata: FrameMetadata?
    @State private var isStreaming = false
    @State private var lastFrameTime: Date?
    @State private var fps: Double = 0
    @FocusState private var isFocused: Bool

    // NotificationCenter publisher for frame events
    private let framePublisher = NotificationCenter.default.publisher(for: .embeddedBrowserFrame)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Keyboard capture layer (invisible, handles keyboard input)
                KeyboardCaptureView(
                    onKeyDown: { event in
                        self.handleKeyDown(event)
                    },
                    onKeyUp: { event in
                        self.handleKeyUp(event)
                    }
                )

                // Frame display
                if let image = self.currentFrame {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Connecting to browser...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                }

                // FPS indicator (debug, top-right corner)
                if self.isStreaming {
                    VStack {
                        HStack {
                            Spacer()
                            Text(String(format: "%.1f FPS", self.fps))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        self.handleMouseMove(at: value.location, in: geometry.size)
                    }
                    .onEnded { value in
                        // Treat short drags (< 5px movement) as clicks
                        let distance = hypot(
                            value.location.x - value.startLocation.x,
                            value.location.y - value.startLocation.y
                        )
                        print("[BrowserStreamView] DragGesture.onEnded - distance: \(distance), location: \(value.location)")
                        if distance < 5 {
                            print("[BrowserStreamView] Treating as click (distance < 5px)")
                            self.handleClick(at: value.location, in: geometry.size)
                        } else {
                            print("[BrowserStreamView] Ignoring drag (distance >= 5px)")
                        }
                    }
            )
        }
        .onReceive(self.framePublisher) { notification in
            self.handleFrameNotification(notification)
        }
        .onAppear {
            print("[BrowserStreamView] View appeared for task: \(self.taskId)")
        }
    }

    // MARK: - Frame Handling

    private func handleFrameNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notifTaskId = userInfo["taskId"] as? String,
              notifTaskId == self.taskId,
              let frameData = userInfo["frame"] as? [String: Any],
              let base64Data = frameData["data"] as? String,
              let imageData = Data(base64Encoded: base64Data),
              let image = NSImage(data: imageData) else {
            return
        }

        // Debug: Log frame receipt periodically (every ~30 frames to avoid spam)
        let hasMetadata = frameData["metadata"] != nil
        if Int.random(in: 0..<30) == 0 {
            print("[BrowserStreamView] Frame received - hasMetadata: \(hasMetadata), taskId: \(notifTaskId)")
        }

        // Update frame and calculate FPS
        let now = Date()
        if let lastTime = self.lastFrameTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed > 0 {
                // Exponential moving average for smoother FPS display
                let instantFps = 1.0 / elapsed
                self.fps = self.fps * 0.9 + instantFps * 0.1
            }
        }
        self.lastFrameTime = now

        self.currentFrame = image
        self.isStreaming = true

        // Extract metadata if available
        if let metadata = frameData["metadata"] as? [String: Any] {
            let newMetadata = FrameMetadata(
                deviceWidth: metadata["deviceWidth"] as? Int ?? 0,
                deviceHeight: metadata["deviceHeight"] as? Int ?? 0,
                pageScaleFactor: metadata["pageScaleFactor"] as? Double ?? 1.0,
                scrollOffsetX: metadata["scrollOffsetX"] as? Double ?? 0,
                scrollOffsetY: metadata["scrollOffsetY"] as? Double ?? 0
            )
            // Log first metadata extraction
            if self.frameMetadata == nil {
                print("[BrowserStreamView] First metadata received - device: \(newMetadata.deviceWidth)x\(newMetadata.deviceHeight)")
            }
            self.frameMetadata = newMetadata
        }
    }

    // MARK: - Input Handling

    private func handleClick(at location: CGPoint, in viewSize: CGSize) {
        guard let metadata = self.frameMetadata else {
            print("[BrowserStreamView] Click ignored - no frame metadata yet")
            return
        }

        guard let browserCoords = self.convertToBrowserCoordinates(
            viewPoint: location,
            viewSize: viewSize,
            deviceSize: CGSize(width: metadata.deviceWidth, height: metadata.deviceHeight)
        ) else {
            print("[BrowserStreamView] Click ignored - invalid device dimensions: \(metadata.deviceWidth)x\(metadata.deviceHeight)")
            return
        }

        print("[BrowserStreamView] Click at view(\(Int(location.x)), \(Int(location.y))) -> browser(\(Int(browserCoords.x)), \(Int(browserCoords.y)))")

        // Send mouse click (pressed + released)
        Task {
            await self.sendMouseEvent(type: "mousePressed", x: browserCoords.x, y: browserCoords.y, button: "left", clickCount: 1)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            await self.sendMouseEvent(type: "mouseReleased", x: browserCoords.x, y: browserCoords.y, button: "left", clickCount: 1)
        }
    }

    private func handleMouseMove(at location: CGPoint, in viewSize: CGSize) {
        guard let metadata = self.frameMetadata else { return }

        guard let browserCoords = self.convertToBrowserCoordinates(
            viewPoint: location,
            viewSize: viewSize,
            deviceSize: CGSize(width: metadata.deviceWidth, height: metadata.deviceHeight)
        ) else { return }

        Task {
            await self.sendMouseEvent(type: "mouseMoved", x: browserCoords.x, y: browserCoords.y)
        }
    }

    private func convertToBrowserCoordinates(viewPoint: CGPoint, viewSize: CGSize, deviceSize: CGSize) -> CGPoint? {
        // Safety check: avoid division by zero
        guard deviceSize.width > 0, deviceSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return nil
        }

        // Calculate the aspect-fit scale
        let viewAspect = viewSize.width / viewSize.height
        let deviceAspect = deviceSize.width / deviceSize.height

        var scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if viewAspect > deviceAspect {
            // View is wider than device, letterboxed on sides
            scale = viewSize.height / deviceSize.height
            offsetX = (viewSize.width - deviceSize.width * scale) / 2
        } else {
            // View is taller than device, letterboxed on top/bottom
            scale = viewSize.width / deviceSize.width
            offsetY = (viewSize.height - deviceSize.height * scale) / 2
        }

        // Convert view coordinates to browser coordinates
        let browserX = (viewPoint.x - offsetX) / scale
        let browserY = (viewPoint.y - offsetY) / scale

        return CGPoint(x: browserX, y: browserY)
    }

    private func sendMouseEvent(
        type: String,
        x: CGFloat,
        y: CGFloat,
        button: String? = nil,
        clickCount: Int? = nil
    ) async {
        await self.taskService.sendEmbeddedMouseEvent(
            taskId: self.taskId,
            type: type,
            x: Int(x),
            y: Int(y),
            button: button,
            clickCount: clickCount
        )
    }

    // MARK: - Keyboard Handling

    private func handleKeyDown(_ event: NSEvent) {
        let keyInfo = self.extractKeyInfo(from: event)
        print("[BrowserStreamView] KeyDown: key=\(keyInfo.key ?? "nil") code=\(keyInfo.code ?? "nil") text=\(keyInfo.text ?? "nil")")

        Task {
            await self.sendKeyEvent(type: "keyDown", key: keyInfo.key, code: keyInfo.code, text: nil, modifiers: keyInfo.modifiers)

            // For printable characters, also send a "char" event with the text
            // Skip control characters (ASCII < 32 or == 127) and empty strings
            if let text = keyInfo.text, !text.isEmpty, self.isPrintableText(text) {
                await self.sendKeyEvent(type: "char", key: nil, code: nil, text: text, modifiers: nil)
            }
        }
    }

    /// Check if text contains only printable characters (no control characters)
    private func isPrintableText(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // Control characters: ASCII 0-31 and 127
            if scalar.value < 32 || scalar.value == 127 {
                return false
            }
        }
        return true
    }

    private func handleKeyUp(_ event: NSEvent) {
        let keyInfo = self.extractKeyInfo(from: event)
        print("[BrowserStreamView] KeyUp: key=\(keyInfo.key ?? "nil") code=\(keyInfo.code ?? "nil")")

        Task {
            await self.sendKeyEvent(type: "keyUp", key: keyInfo.key, code: keyInfo.code, text: nil, modifiers: keyInfo.modifiers)
        }
    }

    private func extractKeyInfo(from event: NSEvent) -> (key: String?, code: String?, text: String?, modifiers: Int) {
        // Map NSEvent keyCode to CDP key names
        let key = Self.keyCodeToKeyName(event.keyCode)
        let code = Self.keyCodeToCode(event.keyCode)

        // Get the character for printable keys
        let text = event.characters

        // Convert modifier flags to CDP bitmask: 1=Alt, 2=Ctrl, 4=Meta, 8=Shift
        var modifiers = 0
        if event.modifierFlags.contains(.option) { modifiers |= 1 }
        if event.modifierFlags.contains(.control) { modifiers |= 2 }
        if event.modifierFlags.contains(.command) { modifiers |= 4 }
        if event.modifierFlags.contains(.shift) { modifiers |= 8 }

        return (key, code, text, modifiers)
    }

    private func sendKeyEvent(
        type: String,
        key: String?,
        code: String?,
        text: String?,
        modifiers: Int?
    ) async {
        await self.taskService.sendEmbeddedKeyEvent(
            taskId: self.taskId,
            type: type,
            key: key,
            code: code,
            text: text,
            modifiers: modifiers
        )
    }

    // MARK: - Key Code Mapping

    /// Maps macOS keyCode to CDP key names (e.g., "Enter", "Backspace", "a")
    private static func keyCodeToKeyName(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 36: return "Enter"
        case 48: return "Tab"
        case 49: return " "  // Space
        case 51: return "Backspace"
        case 53: return "Escape"
        case 117: return "Delete"
        case 123: return "ArrowLeft"
        case 124: return "ArrowRight"
        case 125: return "ArrowDown"
        case 126: return "ArrowUp"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "PageUp"
        case 121: return "PageDown"
        // Letter keys (a-z)
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "o"
        case 32: return "u"
        case 33: return "["
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 39: return "'"
        case 40: return "k"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 50: return "`"
        default: return nil
        }
    }

    /// Maps macOS keyCode to CDP physical key codes (e.g., "Enter", "KeyA")
    private static func keyCodeToCode(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 36: return "Enter"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Backspace"
        case 53: return "Escape"
        case 117: return "Delete"
        case 123: return "ArrowLeft"
        case 124: return "ArrowRight"
        case 125: return "ArrowDown"
        case 126: return "ArrowUp"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "PageUp"
        case 121: return "PageDown"
        // Letter keys use "KeyA" format
        case 0: return "KeyA"
        case 1: return "KeyS"
        case 2: return "KeyD"
        case 3: return "KeyF"
        case 4: return "KeyH"
        case 5: return "KeyG"
        case 6: return "KeyZ"
        case 7: return "KeyX"
        case 8: return "KeyC"
        case 9: return "KeyV"
        case 11: return "KeyB"
        case 12: return "KeyQ"
        case 13: return "KeyW"
        case 14: return "KeyE"
        case 15: return "KeyR"
        case 16: return "KeyY"
        case 17: return "KeyT"
        case 18: return "Digit1"
        case 19: return "Digit2"
        case 20: return "Digit3"
        case 21: return "Digit4"
        case 22: return "Digit6"
        case 23: return "Digit5"
        case 24: return "Equal"
        case 25: return "Digit9"
        case 26: return "Digit7"
        case 27: return "Minus"
        case 28: return "Digit8"
        case 29: return "Digit0"
        case 30: return "BracketRight"
        case 31: return "KeyO"
        case 32: return "KeyU"
        case 33: return "BracketLeft"
        case 34: return "KeyI"
        case 35: return "KeyP"
        case 37: return "KeyL"
        case 38: return "KeyJ"
        case 39: return "Quote"
        case 40: return "KeyK"
        case 41: return "Semicolon"
        case 42: return "Backslash"
        case 43: return "Comma"
        case 44: return "Slash"
        case 45: return "KeyN"
        case 46: return "KeyM"
        case 47: return "Period"
        case 50: return "Backquote"
        default: return nil
        }
    }
}

// MARK: - Supporting Types

struct FrameMetadata {
    let deviceWidth: Int
    let deviceHeight: Int
    let pageScaleFactor: Double
    let scrollOffsetX: Double
    let scrollOffsetY: Double
}

// MARK: - Keyboard Capture View

/// NSViewRepresentable that captures keyboard events and forwards them to handlers.
/// This is needed because SwiftUI doesn't have native keyboard event capture for arbitrary keys.
struct KeyboardCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void
    let onKeyUp: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyboardNSView {
        let view = KeyboardNSView()
        view.onKeyDown = self.onKeyDown
        view.onKeyUp = self.onKeyUp
        return view
    }

    func updateNSView(_ nsView: KeyboardNSView, context: Context) {
        nsView.onKeyDown = self.onKeyDown
        nsView.onKeyUp = self.onKeyUp
    }
}

/// Custom NSView that can become first responder and capture keyboard events.
final class KeyboardNSView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    var onKeyUp: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        print("[KeyboardNSView] becomeFirstResponder")
        return true
    }

    override func resignFirstResponder() -> Bool {
        print("[KeyboardNSView] resignFirstResponder")
        return true
    }

    override func keyDown(with event: NSEvent) {
        print("[KeyboardNSView] keyDown: keyCode=\(event.keyCode) chars=\(event.characters ?? "nil")")
        self.onKeyDown?(event)
        // Don't call super to prevent beep sound for unhandled keys
    }

    override func keyUp(with event: NSEvent) {
        print("[KeyboardNSView] keyUp: keyCode=\(event.keyCode)")
        self.onKeyUp?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier key changes (Shift, Control, Option, Command)
        print("[KeyboardNSView] flagsChanged: modifiers=\(event.modifierFlags.rawValue)")
        // Could forward modifier-only events if needed
    }

    override func mouseDown(with event: NSEvent) {
        // Become first responder when clicked
        self.window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Attempt to become first responder when added to window
        if self.window != nil {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }
}

// Notification names are defined in TaskService.swift:
// .embeddedBrowserFrame, .embeddedBrowserStarted, .embeddedBrowserStopped
