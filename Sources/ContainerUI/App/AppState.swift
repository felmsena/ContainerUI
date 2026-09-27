import SwiftUI

/// A request to present the Run sheet, pre-filled with `spec`.
struct RunRequest: Identifiable {
    let id = UUID()
    var spec: RunSpec
}

/// Window-level UI state — navigation, selections and globally presented
/// sheets — kept apart from `ContainerService`, which only owns CLI data.
/// Lets any view (command palette, menu bar, a detail view) navigate or
/// open a sheet without threading bindings through the hierarchy.
@MainActor
@Observable
final class AppState {
    var sidebarItem: SidebarItem = .containers
    var showCommandPalette = false
    var runRequest: RunRequest?
    var showPullSheet = false
    var showCreateVolumeSheet = false

    var selectedContainer: ContainerInfo?
    var selectedImage: ImageInfo?
    var selectedRegistryEntry: RegistryEntry?
    var selectedVolume: VolumeInfo?
    var selectedGroup: URL?

    func runContainer(_ spec: RunSpec = RunSpec()) {
        runRequest = RunRequest(spec: spec)
    }

    func show(_ item: SidebarItem) {
        sidebarItem = item
    }
}
