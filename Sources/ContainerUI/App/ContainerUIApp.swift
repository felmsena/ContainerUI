import SwiftUI

@main
struct ContainerUIApp: App {
    @State private var service = ContainerService()
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup(id: "main-window") {
            ContentView()
                .environment(service)
                .environment(app)
                .background(WindowChrome().frame(width: 0, height: 0))
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh") {
                    Task { await service.refresh(app.sidebarItem) }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Search…") {
                    app.showCommandPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) {
                Button("Run Container…") {
                    app.runContainer()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                ForEach(Array(SidebarItem.allCases.filter { $0 != .settings }.enumerated()), id: \.element) { index, item in
                    Button(LocalizedStringKey(item.rawValue)) {
                        app.sidebarItem = item
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(service)
                .environment(app)
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
