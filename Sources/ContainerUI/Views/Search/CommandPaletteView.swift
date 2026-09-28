import SwiftUI

/// One entry in the palette: a place to go or a thing to do.
private struct PaletteItem: Identifiable {
    enum Kind { case action, container, image, volume, network, section }

    let id: String
    let kind: Kind
    let icon: String
    let title: String
    let subtitle: String
    let perform: @MainActor () -> Void

    var sortRank: Int { kind == .action ? 0 : 1 }
}

/// Spotlight-style overlay (⌘K): searches containers, images, volumes and
/// networks, and runs commands — start/stop/restart/shell for a container,
/// run, pull, build, create, refresh, and jump to any section.
struct CommandPaletteView: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFieldFocused: Bool

    private var items: [PaletteItem] {
        var result: [PaletteItem] = globalActions
        for c in service.containers {
            result.append(PaletteItem(id: "c-\(c.id)", kind: .container, icon: "square.stack.3d.up",
                                      title: c.id, subtitle: c.shortImage) {
                app.selectedContainer = c
                app.sidebarItem = .containers
            })
            result += containerActions(c)
        }
        for i in service.images {
            result.append(PaletteItem(id: "i-\(i.id)", kind: .image, icon: "shippingbox",
                                      title: i.shortName, subtitle: i.tag) {
                app.selectedImage = i
                app.sidebarItem = .images
            })
            result.append(PaletteItem(id: "run-\(i.id)", kind: .action, icon: "play.fill",
                                      title: String(localized: "Run \(i.ref)"), subtitle: String(localized: "Image")) {
                app.runContainer(RunSpec(image: i.ref))
            })
        }
        for v in service.volumes {
            result.append(PaletteItem(id: "v-\(v.id)", kind: .volume, icon: "externaldrive",
                                      title: v.name, subtitle: v.driver) {
                app.selectedVolume = v
                app.sidebarItem = .volumes
            })
        }
        for n in service.networks {
            result.append(PaletteItem(id: "n-\(n.id)", kind: .network, icon: "network",
                                      title: n.name, subtitle: n.subnet) {
                app.selectedNetwork = n
                app.sidebarItem = .networks
            })
        }
        for section in SidebarItem.allCases {
            result.append(PaletteItem(id: "s-\(section.rawValue)", kind: .section, icon: section.icon,
                                      title: String(localized: "Go to \(String(localized: String.LocalizationValue(section.rawValue)))"),
                                      subtitle: String(localized: "Section")) {
                app.sidebarItem = section
            })
        }
        return result
    }

    private var globalActions: [PaletteItem] {
        [
            PaletteItem(id: "a-run", kind: .action, icon: "play.rectangle", title: String(localized: "Run container…"), subtitle: "⌘N") {
                app.runContainer()
            },
            PaletteItem(id: "a-pull", kind: .action, icon: "arrow.down.circle", title: String(localized: "Pull image…"), subtitle: "") {
                app.showPullSheet = true
            },
            PaletteItem(id: "a-build", kind: .action, icon: "hammer", title: String(localized: "Build image…"), subtitle: "") {
                app.sidebarItem = .build
            },
            PaletteItem(id: "a-volume", kind: .action, icon: "externaldrive.badge.plus", title: String(localized: "Create volume…"), subtitle: "") {
                app.showCreateVolumeSheet = true
            },
            PaletteItem(id: "a-network", kind: .action, icon: "network", title: String(localized: "Create network…"), subtitle: "") {
                app.showCreateNetworkSheet = true
            },
            PaletteItem(id: "a-refresh", kind: .action, icon: "arrow.clockwise", title: String(localized: "Refresh"), subtitle: "⌘R") {
                Task { await service.refresh(app.sidebarItem) }
            },
            service.daemonState == .running
                ? PaletteItem(id: "a-svc", kind: .action, icon: "stop.circle", title: String(localized: "Stop the container service"), subtitle: "") {
                    Task { await service.stopDaemon() }
                }
                : PaletteItem(id: "a-svc", kind: .action, icon: "play.circle", title: String(localized: "Start the container service"), subtitle: "") {
                    Task { await service.startDaemon() }
                },
        ]
    }

    private func containerActions(_ c: ContainerInfo) -> [PaletteItem] {
        if c.state.isRunning {
            return [
                PaletteItem(id: "stop-\(c.id)", kind: .action, icon: "stop.fill", title: String(localized: "Stop \(c.id)"), subtitle: c.shortImage) {
                    Task { await service.stop(c.id) }
                },
                PaletteItem(id: "restart-\(c.id)", kind: .action, icon: "arrow.clockwise", title: String(localized: "Restart \(c.id)"), subtitle: c.shortImage) {
                    Task { await service.restart(c.id) }
                },
                PaletteItem(id: "shell-\(c.id)", kind: .action, icon: "terminal", title: String(localized: "Open shell in \(c.id)"), subtitle: c.shortImage) {
                    service.openShell(for: c.id)
                },
            ]
        }
        return [
            PaletteItem(id: "start-\(c.id)", kind: .action, icon: "play.fill", title: String(localized: "Start \(c.id)"), subtitle: c.shortImage) {
                Task { await service.start(c.id) }
            },
        ]
    }

    /// Without a query: actions and containers only (a short, useful list).
    /// With one: every item whose words all match, actions first.
    private var results: [PaletteItem] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else {
            return items.filter { $0.kind == .action && !$0.id.hasPrefix("run-") || $0.kind == .container }.prefix(30).map { $0 }
        }
        return items
            .filter { item in
                let haystack = (item.title + " " + item.subtitle).lowercased()
                return words.allSatisfy(haystack.contains)
            }
            .sorted { $0.sortRank < $1.sortRank }
            .prefix(50).map { $0 }
    }

    var body: some View {
        let results = self.results
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { app.showCommandPalette = false }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.text3)
                    TextField("Search or type a command…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .focused($isFieldFocused)
                        .onChange(of: query) { _, _ in selectedIndex = 0 }
                }
                .padding(14)

                Divider()

                if results.isEmpty {
                    Text("No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text2)
                        .padding(20)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                    row(item, isSelected: index == selectedIndex)
                                        .id(item.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture { run(item) }
                                }
                            }
                        }
                        .frame(maxHeight: 340)
                        .onChange(of: selectedIndex) { _, newValue in
                            guard results.indices.contains(newValue) else { return }
                            proxy.scrollTo(results[newValue].id, anchor: .center)
                        }
                    }
                }

                Divider()

                HStack(spacing: 14) {
                    Label("navigate", systemImage: "arrow.up.arrow.down")
                    Label("run", systemImage: "return")
                    Label("close", systemImage: "escape")
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.text3)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
                    .shadow(color: Theme.shadow, radius: 24, y: 12)
            )
            .frame(width: 520)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onKeyPress(.escape) {
            app.showCommandPalette = false
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(max(results.count - 1, 0), selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            if results.indices.contains(selectedIndex) { run(results[selectedIndex]) }
            return .handled
        }
        .task { isFieldFocused = true }
    }

    private func row(_ item: PaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .frame(width: 18)
                .foregroundStyle(item.kind == .action ? Theme.accent : Theme.text2)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Theme.accentSoft : Color.clear)
    }

    private func run(_ item: PaletteItem) {
        app.showCommandPalette = false
        item.perform()
    }
}
