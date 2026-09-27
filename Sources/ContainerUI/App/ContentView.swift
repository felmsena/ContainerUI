import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable {
    case containers = "Containers"
    case images     = "Images"
    case volumes    = "Volumes"
    case registry   = "Registry"
    case build      = "Build"
    case groups     = "Groups"
    case stats      = "Stats"
    case logs       = "Logs"
    case settings   = "Settings"

    var icon: String {
        switch self {
        case .containers: return "square.stack.3d.up"
        case .images:     return "shippingbox"
        case .volumes:    return "externaldrive"
        case .registry:   return "storefront"
        case .build:      return "hammer"
        case .groups:     return "rectangle.3.group"
        case .stats:      return "chart.bar"
        case .logs:       return "terminal"
        case .settings:   return "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system

    var body: some View {
        VStack(spacing: 0) {
            banners
            splitView
        }
        .animation(.easeOut(duration: 0.2), value: service.serviceError)
        .animation(.easeOut(duration: 0.2), value: service.availableUpdate)
        .preferredColorScheme(appAppearance.colorScheme)
    }

    @ViewBuilder
    private var banners: some View {
        if service.serviceError != nil || service.availableUpdate != nil {
            VStack(spacing: 8) {
                if let error = service.serviceError {
                    ErrorBanner(message: error) {
                        service.serviceError = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let release = service.availableUpdate {
                    ErrorBanner(
                        message: String(localized: "ContainerUI \(release.tagName) is available"),
                        style: .info,
                        actionLabel: String(localized: "Download"),
                        action: {
                            if let url = URL(string: release.htmlUrl) { NSWorkspace.shared.open(url) }
                        }
                    ) {
                        service.availableUpdate = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var splitView: some View {
        @Bindable var app = app
        return NavigationSplitView {
            SidebarView(selected: $app.sidebarItem)
                .navigationSplitViewColumnWidth(min: 224, ideal: 248, max: 280)
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ActivityToolbarButton()
            }
        }
        .modifier(SelectionSync())
        .modifier(GlobalSheets())
        .tint(Theme.accent)
        .background(Theme.bg)
        .toolbarBackground(Theme.bg, for: .windowToolbar)
    }

    @ViewBuilder
    private var contentColumn: some View {
        @Bindable var app = app
        switch app.sidebarItem {
        case .containers: ContainerListView(selected: $app.selectedContainer)
        case .images:     ImagesView(selected: $app.selectedImage)
        case .volumes:    VolumesView(selected: $app.selectedVolume)
        case .registry:   RegistryView(selectedEntry: $app.selectedRegistryEntry)
        case .build:      BuildView()
        case .groups:     GroupsView(selected: $app.selectedGroup)
        case .stats:      SystemStatsView()
        case .logs:       SystemLogsView()
        case .settings:   SettingsView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch app.sidebarItem {
        case .containers:
            if let container = app.selectedContainer {
                DetailView(container: container).id(container.id)
            } else {
                EmptyStateView(icon: "square.stack.3d.up", title: "Select a container")
            }
        case .images:
            if let image = app.selectedImage {
                ImageDetailView(image: image).id(image.id)
            } else {
                EmptyStateView(icon: "shippingbox", title: "Select an image")
            }
        case .registry:
            if let entry = app.selectedRegistryEntry {
                RegistryDetailView(entry: entry).id(entry.id)
            } else {
                EmptyStateView(icon: "storefront", title: "Select a registry entry")
            }
        case .volumes:
            if let volume = app.selectedVolume {
                VolumeDetailView(volume: volume).id(volume.id)
            } else {
                EmptyStateView(icon: "externaldrive", title: "Select a volume")
            }
        case .groups:
            if let group = app.selectedGroup {
                GroupDetailView(fileURL: group).id(group)
            } else {
                EmptyStateView(icon: "rectangle.3.group", title: "Select a group")
            }
        default:
            EmptyStateView(icon: app.sidebarItem.icon, title: LocalizedStringKey(app.sidebarItem.rawValue))
        }
    }
}

/// Keeps selections pointing at the freshest copy of each item, and drops
/// them when the item disappears (removed here or via the CLI), so the
/// detail pane never shows something that no longer exists.
private struct SelectionSync: ViewModifier {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    func body(content: Content) -> some View {
        content
            .onChange(of: service.containers) { _, containers in
                if let selected = app.selectedContainer {
                    app.selectedContainer = containers.first { $0.id == selected.id }
                }
            }
            .onChange(of: service.images) { _, images in
                if let selected = app.selectedImage {
                    app.selectedImage = images.first { $0.id == selected.id }
                }
            }
            .onChange(of: service.volumes) { _, volumes in
                if let selected = app.selectedVolume {
                    app.selectedVolume = volumes.first { $0.id == selected.id }
                }
            }
            .onChange(of: app.sidebarItem) { _, _ in
                app.selectedRegistryEntry = nil
            }
    }
}

/// Sheets and overlays any view can trigger through `AppState`.
private struct GlobalSheets: ViewModifier {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    func body(content: Content) -> some View {
        @Bindable var app = app
        content
            .overlay { ToastOverlay() }
            .overlay {
                if app.showCommandPalette {
                    CommandPaletteView()
                }
            }
            .sheet(item: $app.runRequest) { request in
                RunContainerSheet(spec: request.spec)
                    .environment(service)
            }
            .sheet(isPresented: $app.showPullSheet) {
                PullImageSheet(isPresented: $app.showPullSheet)
                    .environment(service)
            }
            .sheet(isPresented: $app.showCreateVolumeSheet) {
                CreateVolumeSheet(isPresented: $app.showCreateVolumeSheet)
                    .environment(service)
            }
    }
}
