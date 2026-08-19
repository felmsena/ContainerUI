import SwiftUI
import AppKit

/// macOS paints the titlebar on its own, outside the SwiftUI view tree. This
/// makes it transparent and sets the window background to `Theme.bg`, so the
/// titlebar and the content read as one continuous surface instead of a gray
/// system bar sitting on top of the themed content.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: view.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Theme.bg)
        window.isMovableByWindowBackground = true
    }
}
