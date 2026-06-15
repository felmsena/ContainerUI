import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable {
    case containers = "Containers"
    case images     = "Images"
    case volumes    = "Volumes"
    case registry   = "Registry"
    case stats      = "Stats"
    case logs       = "Logs"
    case settings   = "Settings"

    var icon: String {
        switch self {
        case .containers: return "square.stack.3d.up"
        case .images:     return "shippingbox"
        case .volumes:    return "externaldrive"
        case .registry:   return "storefront"
        case .stats:      return "chart.bar"
        case .logs:       return "terminal"
        case .settings:   return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var service: ContainerService
    @State private var sidebarItem: SidebarItem = .containers
    @State private var selectedContainer: ContainerInfo?
    @State private var selectedImage: ImageInfo?
    @State private var selectedRegistryEntry: RegistryEntry?
    @State private var selectedVolume: VolumeInfo?

    var body: some View {
        NavigationSplitView {
            SidebarView(selected: $sidebarItem)
        } content: {
            switch sidebarItem {
            case .containers: ContainerListView(selected: $selectedContainer)
            case .images:     ImagesView(selected: $selectedImage)
            case .volumes:    VolumesView(selected: $selectedVolume)
            case .registry:   RegistryView(selectedEntry: $selectedRegistryEntry)
            case .stats:      SystemStatsView()
            case .logs:       SystemLogsView()
            case .settings:   SettingsView()
            }
        } detail: {
            switch sidebarItem {
            case .containers:
                if let container = selectedContainer {
                    DetailView(container: container).id(container.id)
                } else {
                    emptyDetail(icon: "square.stack.3d.up", text: "Select a container")
                }
            case .images:
                if let image = selectedImage {
                    ImageDetailView(image: image).id(image.id)
                } else {
                    emptyDetail(icon: "shippingbox", text: "Select an image")
                }
            case .registry:
                if let entry = selectedRegistryEntry {
                    RegistryDetailView(entry: entry)
                        .id(entry.id)
                } else {
                    emptyDetail(icon: "storefront", text: "Select an image")
                }
            case .volumes:
                if let volume = selectedVolume {
                    VolumeDetailView(volume: volume)
                        .id(volume.id)
                } else {
                    emptyDetail(icon: "externaldrive", text: "Select a volume")
                }
            default:
                emptyDetail(icon: sidebarItem.icon, text: sidebarItem.rawValue)
            }
        }
        .onChange(of: service.containers) { _, _ in
            if let selected = selectedContainer,
               let updated = service.containers.first(where: { $0.id == selected.id }) {
                selectedContainer = updated
            }
        }
        .onChange(of: sidebarItem) { _, _ in
            selectedRegistryEntry = nil
        }
    }

    @ViewBuilder
    func emptyDetail(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
