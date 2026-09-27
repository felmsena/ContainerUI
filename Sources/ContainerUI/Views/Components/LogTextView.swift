import SwiftUI
import AppKit

/// Read-only, selectable, monospaced log viewer backed by `NSTextView`.
///
/// A SwiftUI `Text` re-lays out the entire string on every change, which
/// crawls once a log reaches thousands of lines. This appends only the new
/// suffix when the text grows, keeps the native find bar (⌘F), and only
/// follows the end of the log when the user is already scrolled to the
/// bottom — scrolling up to read something isn't interrupted.
struct LogTextView: NSViewRepresentable {
    let text: String
    var fontSize: CGFloat = 11

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor(Theme.text2)
        textView.textContainer?.widthTracksTextView = true

        context.coordinator.apply(text, to: textView, in: scrollView, forceScroll: true)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        context.coordinator.apply(text, to: textView, in: scrollView, forceScroll: false)
    }

    final class Coordinator {
        private var shown = ""

        func apply(_ text: String, to textView: NSTextView, in scrollView: NSScrollView, forceScroll: Bool) {
            guard text != shown else { return }
            let wasAtBottom = forceScroll || Self.isAtBottom(scrollView)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor(Theme.text2),
            ]
            guard let storage = textView.textStorage else { return }
            if !shown.isEmpty, text.hasPrefix(shown) {
                let suffix = String(text[shown.endIndex...])
                storage.append(NSAttributedString(string: suffix, attributes: attributes))
            } else {
                storage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
            }
            shown = text
            if wasAtBottom { textView.scrollToEndOfDocument(nil) }
        }

        private static func isAtBottom(_ scrollView: NSScrollView) -> Bool {
            guard let document = scrollView.documentView else { return true }
            let visible = scrollView.contentView.documentVisibleRect
            return visible.maxY >= document.bounds.maxY - 24
        }
    }
}
