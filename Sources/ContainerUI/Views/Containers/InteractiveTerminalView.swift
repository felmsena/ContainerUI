import SwiftUI
import AppKit
import SwiftTerm

/// A real PTY session inside a running container (`container exec --tty
/// --interactive`), rendered by SwiftTerm. Owns the "session ended" overlay and
/// restarts the process on Reconnect.
struct InteractiveTerminalView: View {
    let containerID: String
    @Environment(ContainerService.self) private var service

    @State private var generation = 0
    @State private var exitCode: Int32?
    @State private var ended = false

    var body: some View {
        TerminalRepresentable(
            bin: service.bin,
            arguments: CLI.execInteractive(id: containerID),
            onTerminated: { code in
                exitCode = code
                ended = true
            }
        )
        .id(generation)
        .padding(8)
        .background(Theme.surface)
        .overlay {
            if ended {
                VStack(spacing: 10) {
                    Image(systemName: "bolt.horizontal.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.text3)
                    Text("Session ended")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    if let exitCode, exitCode != 0 {
                        Text("Exit code \(exitCode)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                    }
                    Button {
                        ended = false
                        exitCode = nil
                        generation += 1
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                }
                .padding(24)
                .background(Theme.surface2.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct TerminalRepresentable: NSViewRepresentable {
    let bin: String
    let arguments: [String]
    let onTerminated: @MainActor (Int32?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(onTerminated: onTerminated) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        applyColors(to: view)
        view.startProcess(executable: bin, args: arguments, environment: Self.environment())
        return view
    }

    func updateNSView(_ view: LocalProcessTerminalView, context: Context) {
        context.coordinator.onTerminated = onTerminated
        applyColors(to: view)
    }

    static func dismantleNSView(_ view: LocalProcessTerminalView, coordinator: Coordinator) {
        coordinator.detach()
        view.terminate()
    }

    private func applyColors(to view: LocalProcessTerminalView) {
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
        func resolve(_ color: SwiftUI.Color) -> NSColor {
            var resolved = NSColor.textColor
            appearance.performAsCurrentDrawingAppearance {
                resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.textColor
            }
            return resolved
        }
        view.nativeBackgroundColor = resolve(Theme.surface)
        view.nativeForegroundColor = resolve(Theme.text)
        view.caretColor = resolve(Theme.accent)
    }

    /// TERM plus the bits of the host environment `container` needs.
    private static func environment() -> [String] {
        let host = ProcessInfo.processInfo.environment
        let path = host["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        return [
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "PATH=\(path)",
            "HOME=\(NSHomeDirectory())",
            "LANG=\(host["LANG"] ?? "en_US.UTF-8")",
        ]
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor LocalProcessTerminalViewDelegate {
        var onTerminated: @MainActor (Int32?) -> Void
        private var detached = false

        init(onTerminated: @escaping @MainActor (Int32?) -> Void) {
            self.onTerminated = onTerminated
        }

        /// Called when the view goes away so a late exit callback doesn't touch dead state.
        func detach() { detached = true }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            guard !detached else { return }
            onTerminated(exitCode)
        }
    }
}
