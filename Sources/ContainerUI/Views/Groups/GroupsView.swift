import SwiftUI
import UniformTypeIdentifiers

struct GroupsView: View {
    @Environment(ContainerService.self) private var service
    @Binding var selected: URL?
    @State private var groupFiles: [URL] = []
    /// Parsed once per load instead of reading every file inside each row's
    /// `body` on every render.
    @State private var parsed: [URL: ComposeGroup] = [:]

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
                        .buttonStyle(BrandButtonStyle(kind: .primary))
                }
            } else {
                List(groupFiles, id: \.self, selection: $selected) { url in
                    GroupRow(fileURL: url, group: parsed[url])
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
        .task { reload() }
        .onChange(of: selected) { _, _ in reload() }
    }

    private func createGroup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "yaml") ?? .plainText]
        panel.nameFieldStringValue = "group.yaml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Self.template.write(to: url, atomically: true, encoding: .utf8)
        ComposeGroupStore.add(url)
        reload()
        selected = url
    }

    private func reload() {
        groupFiles = ComposeGroupStore.load()
        parsed = Dictionary(uniqueKeysWithValues: groupFiles.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  case .success(let group) = ComposeParser.parse(text) else { return nil }
            return (url, group)
        })
    }

    private func openGroup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "yaml") ?? .plainText]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ComposeGroupStore.add(url)
        reload()
        selected = url
    }

    private func remove(_ url: URL) {
        ComposeGroupStore.remove(url)
        reload()
        if selected == url { selected = nil }
    }
}

private struct GroupRow: View {
    @Environment(ContainerService.self) private var service
    let fileURL: URL
    let group: ComposeGroup?

    private var name: String { fileURL.deletingPathExtension().lastPathComponent }

    private var counts: (running: Int, total: Int) {
        guard let group, !group.services.isEmpty else { return (0, 0) }
        let containerNames = Set(group.services.map { ContainerService.composeContainerName(group: name, service: $0.name) })
        let running = service.containers.filter { containerNames.contains($0.id) && $0.state.isRunning }.count
        return (running, containerNames.count)
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Hue.groups.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Hue.groups)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(fileURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            let (running, total) = counts
            if total > 0 {
                Text("\(running)/\(total)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(running > 0 ? Theme.accent : Theme.text2)
            }
        }
        .padding(.vertical, 2)
    }
}
