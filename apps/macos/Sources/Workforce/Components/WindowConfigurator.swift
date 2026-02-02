import AppKit
import SwiftUI

/// Configures the hosting NSWindow for transparent glass appearance.
/// Makes the window background clear so the SwiftUI gradient shows through,
/// and hides the title bar chrome for a seamless glass shell.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
