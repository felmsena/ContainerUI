import SwiftUI

private enum SearchResultKind {
    case container, image, volume

    var icon: String {
        switch self {
        case .container: return "square.stack.3d.up"
        case .image:     return "shippingbox"
        case .volume:    return "externaldrive"
        }
    }
}

private struct SearchResult: Identifiable {
    let id: String
    let kind: SearchResultKind
    let title: String
    let subtitle: String
}

/// Spotlight-style overlay: filters the already-loaded containers/images/
/// volumes arrays (no new fetch) and navigates on selection by setting the
/// sidebar section plus the matching selection binding in `ContentView`.
struct CommandPaletteView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var isPresented: Bool
    @Binding var sidebarItem: SidebarItem
    @Binding var selectedContainer: ContainerInfo?
    @Binding var selectedImage: ImageInfo?
    @Binding var selectedVolume: VolumeInfo?

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFieldFocused: Bool

    private var results: [SearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let containerResults = service.containers.map {
            SearchResult(id: "c-\($0.id)", kind: .container, title: $0.id, subtitle: $0.shortImage)
        }
        let imageResults = service.images.map {
            SearchResult(id: "i-\($0.id)", kind: .image, title: $0.shortName, subtitle: $0.tag)
        }
        let volumeResults = service.volumes.map {
            SearchResult(id: "v-\($0.id)", kind: .volume, title: $0.name, subtitle: $0.driver)
        }

        let all = containerResults + imageResults + volumeResults
        guard !needle.isEmpty else { return Array(all.prefix(30)) }

        return all.filter {
            $0.title.lowercased().contains(needle) || $0.subtitle.lowercased().contains(needle)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search containers, images, volumes…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isFieldFocused)
                        .onChange(of: query) { _, _ in selectedIndex = 0 }
                }
                .padding(14)

                Divider()

                if results.isEmpty {
                    Text(query.isEmpty ? "Nothing to search yet" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(20)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    resultRow(result, isSelected: index == selectedIndex)
                                        .id(result.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture { select(result) }
                                }
                            }
                        }
                        .frame(maxHeight: 320)
                        .onChange(of: selectedIndex) { _, newValue in
                            guard results.indices.contains(newValue) else { return }
                            proxy.scrollTo(results[newValue].id, anchor: .center)
                        }
                    }
                }

                Divider()

                HStack(spacing: 14) {
                    Label("navigate", systemImage: "arrow.up.arrow.down")
                    Label("select", systemImage: "return")
                    Label("close", systemImage: "escape")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
            )
            .frame(width: 480)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.return) {
            selectCurrent()
            return .handled
        }
        .task { isFieldFocused = true }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResult, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result.kind.icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                Text(result.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    private func selectCurrent() {
        guard results.indices.contains(selectedIndex) else { return }
        select(results[selectedIndex])
    }

    private func select(_ result: SearchResult) {
        switch result.kind {
        case .container:
            selectedContainer = service.containers.first { $0.id == String(result.id.dropFirst(2)) }
            sidebarItem = .containers
        case .image:
            selectedImage = service.images.first { $0.id == String(result.id.dropFirst(2)) }
            sidebarItem = .images
        case .volume:
            selectedVolume = service.volumes.first { $0.id == String(result.id.dropFirst(2)) }
            sidebarItem = .volumes
        }
        isPresented = false
    }
}
