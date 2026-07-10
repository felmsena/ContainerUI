import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable {
    case containers = "Containers"
    case images     = "Images"
    case volumes    = "Volumes"
    case registry   = "Registry"
    case build      = "Build"
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
        case .stats:      return "chart.bar"
        case .logs:       return "terminal"
        case .settings:   return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var service: ContainerService
    @State private var selectedContainer: ContainerInfo?
    @State private var selectedImage: ImageInfo?
    @State private var selectedRegistryEntry: RegistryEntry?
    @State private var selectedVolume: VolumeInfo?

    var body: some View {
        NavigationSplitView {
            SidebarView(selected: $service.sidebarItem)
        } content: {
            switch service.sidebarItem {
            case .containers: ContainerListView(selected: $selectedContainer)
            case .images:     ImagesView(selected: $selectedImage)
            case .volumes:    VolumesView(selected: $selectedVolume)
            case .registry:   RegistryView(selectedEntry: $selectedRegistryEntry)
            case .build:      BuildView(sidebarItem: $service.sidebarItem, selectedImage: $selectedImage)
            case .stats:      SystemStatsView()
            case .logs:       SystemLogsView()
            case .settings:   SettingsView()
            }
        } detail: {
            switch service.sidebarItem {
            case .containers:
                if let container = selectedContainer {
                    DetailView(container: container).id(container.id)
                } else {
                    EmptyStateView(icon: "square.stack.3d.up", title: "Select a container")
                }
            case .images:
                if let image = selectedImage {
                    ImageDetailView(image: image).id(image.id)
                } else {
                    EmptyStateView(icon: "shippingbox", title: "Select an image")
                }
            case .registry:
                if let entry = selectedRegistryEntry {
                    RegistryDetailView(entry: entry)
                        .id(entry.id)
                } else {
                    EmptyStateView(icon: "storefront", title: "Select a registry entry")
                }
            case .volumes:
                if let volume = selectedVolume {
                    VolumeDetailView(volume: volume)
                        .id(volume.id)
                } else {
                    EmptyStateView(icon: "externaldrive", title: "Select a volume")
                }
            default:
                EmptyStateView(icon: service.sidebarItem.icon, title: LocalizedStringKey(service.sidebarItem.rawValue))
            }
        }
        .onChange(of: service.containers) { _, _ in
            if let selected = selectedContainer,
               let updated = service.containers.first(where: { $0.id == selected.id }) {
                selectedContainer = updated
            }
        }
        .onChange(of: service.sidebarItem) { _, _ in
            selectedRegistryEntry = nil
        }
        .overlay {
            if service.showCommandPalette {
                CommandPaletteView(
                    isPresented: $service.showCommandPalette,
                    sidebarItem: $service.sidebarItem,
                    selectedContainer: $selectedContainer,
                    selectedImage: $selectedImage,
                    selectedVolume: $selectedVolume
                )
            }
        }
        .sheet(isPresented: $service.showRunSheet) {
            RunContainerSheet(imageRef: "", defaultPorts: [], defaultMemory: "512M", defaultEnv: [])
                .environmentObject(service)
        }
        .overlay(alignment: .top) {
            if let error = service.serviceError {
                ErrorBanner(message: error) {
                    service.serviceError = nil
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: service.serviceError)
    }
}
