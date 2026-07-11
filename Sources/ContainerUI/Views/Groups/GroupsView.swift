import SwiftUI
import UniformTypeIdentifiers

struct GroupsView: View {
    @EnvironmentObject var service: ContainerService
    @Binding var selected: URL?
    @State private var groupFiles: [URL] = []

    private static let template = """
    services:
      example:
        image: alpine:latest
    """

    var body: some View {
        VStack(spacing: 0) {
            if groupFiles.isEmpty {
                EmptyStateView(
                    icon: "rectangle.3.group",
                    title: "No groups",
                    subtitle: "Create a compose-lite YAML file to run several containers together."
                ) {
                    Button("New Group…", action: createGroup)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(groupFiles, id: \.self, selection: $selected) { url in
                    GroupRow(fileURL: url)
                        .tag(url)
                        .contextMenu {
                            Button("Remove from list", role: .destructive) { remove(url) }
                        }
                }
                .listStyle(.sidebar)
            }

            Divider()
            HStack {
                Button("New Group…", action: createGroup)
                    .buttonStyle(.borderless)
                Spacer()
                Button("Open…", action: openGroup)
                    .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .padding(8)
        }
        .navigationTitle("Groups")
        .task { groupFiles = ComposeGroupStore.load() }
    }

    private func createGroup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "yaml") ?? .plainText]
        panel.nameFieldStringValue = "group.yaml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Self.template.write(to: url, atomically: true, encoding: .utf8)
        ComposeGroupStore.add(url)
        groupFiles = ComposeGroupStore.load()
        selected = url
    }

    private func openGroup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "yaml") ?? .plainText]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ComposeGroupStore.add(url)
        groupFiles = ComposeGroupStore.load()
        selected = url
    }

    private func remove(_ url: URL) {
        ComposeGroupStore.remove(url)
        groupFiles = ComposeGroupStore.load()
        if selected == url { selected = nil }
    }
}

private struct GroupRow: View {
    @EnvironmentObject var service: ContainerService
    let fileURL: URL

    private var name: String { fileURL.deletingPathExtension().lastPathComponent }

    private var counts: (running: Int, total: Int) {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
              case .success(let group) = ComposeParser.parse(text),
              !group.services.isEmpty
        else { return (0, 0) }
        let containerNames = Set(group.services.map { ContainerService.composeContainerName(group: name, service: $0.name) })
        let running = service.containers.filter { containerNames.contains($0.id) && $0.state.isRunning }.count
        return (running, containerNames.count)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                Text(fileURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            let (running, total) = counts
            if total > 0 {
                Text("\(running)/\(total)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(running > 0 ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
