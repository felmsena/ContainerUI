import SwiftUI

@main
struct ContainerUIApp: App {
    @StateObject private var service = ContainerService()

    var body: some Scene {
        WindowGroup(id: "main-window") {
            ContentView()
                .environmentObject(service)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh containers") {
                    Task { await service.fetchContainers() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Search…") {
                    service.showCommandPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(service)
        } label: {
            MenuBarLabel(runningCount: service.containers.filter { $0.state.isRunning }.count,
                         hasError: service.serviceError != nil)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let runningCount: Int
    let hasError: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: hasError
                  ? "square.stack.3d.up.trianglebadge.exclamationmark"
                  : "square.stack.3d.up.fill")
            .font(.system(size: 13))

            if runningCount > 0 {
                Text("\(runningCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
    }
}
