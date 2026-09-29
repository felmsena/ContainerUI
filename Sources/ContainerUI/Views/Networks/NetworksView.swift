import SwiftUI

struct NetworksView: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @Binding var selected: NetworkInfo?
    @State private var searchText = ""
    @State private var showPruneAlert = false

    private var filtered: [NetworkInfo] {
        guard !searchText.isEmpty else { return service.networks }
        return service.networks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.subnet.contains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $searchText, prompt: "Search networks…")
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.bg)

            if service.networks.isEmpty {
                EmptyStateView(icon: "network", title: "No networks") {
                    Button("Create network") { app.showCreateNetworkSheet = true }
                        .buttonStyle(BrandButtonStyle(kind: .primary))
                }
            } else if filtered.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "No results for \"\(searchText)\"")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { network in
                            NetworkRowView(network: network, isSelected: selected?.id == network.id)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = network }
                        }
                    }
                    .padding(12)
                }
                .background(Theme.bg)
                .listKeyboardNavigation(items: filtered, selection: $selected)
            }
        }
        .navigationTitle("Networks")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await service.refresh(.networks) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh networks")

                Button {
                    showPruneAlert = true
                } label: {
                    Image(systemName: "trash.slash")
                }
                .help("Remove networks with no containers attached")
                .accessibilityLabel("Prune unused networks")

                Button {
                    app.showCreateNetworkSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create network")
                .accessibilityLabel("Create network")
            }
        }
        .task { await service.refresh(.networks) }
        .alert("Remove unused networks?", isPresented: $showPruneAlert) {
            Button("Remove", role: .destructive) {
                Task { await service.pruneNetworks() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Networks with no containers attached will be deleted.")
        }
    }
}

struct NetworkRowView: View {
    let network: NetworkInfo
    let isSelected: Bool
    @Environment(ContainerService.self) private var service

    var body: some View {
        let attached = service.containers(on: network).count
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Hue.networks.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Hue.networks)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(network.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if network.isBuiltin {
                        Text("built-in")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Theme.text3)
                    }
                }
                HStack(spacing: 6) {
                    Text(network.subnet.isEmpty ? "—" : network.subnet)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.text2)
                    if !network.mode.isEmpty {
                        Text("·").foregroundStyle(Theme.text3).font(.system(size: 11))
                        Text(network.mode.uppercased())
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }

            Spacer()

            if attached > 0 {
                Label("\(attached)", systemImage: "square.stack.3d.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .help("Containers attached")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Theme.accentSoft : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
                )
        )
    }
}

struct NetworkDetailView: View {
    let network: NetworkInfo
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app
    @State private var showDeleteAlert = false

    private var attached: [ContainerInfo] { service.containers(on: network) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHero(icon: "network", color: Theme.Hue.networks, title: network.name) {
                    if network.isBuiltin {
                        HeroBadge(text: String(localized: "built-in"), color: Theme.text3)
                    }
                    if !network.mode.isEmpty {
                        HeroBadge(text: network.mode.uppercased(), color: Theme.Hue.networks)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Details")
                    KeyValueRow(key: String(localized: "Name"), value: network.name)
                    KeyValueRow(key: String(localized: "IPv4 subnet"), value: network.subnet)
                    KeyValueRow(key: String(localized: "Gateway"), value: network.gateway)
                    if !network.ipv6Subnet.isEmpty {
                        KeyValueRow(key: String(localized: "IPv6 subnet"), value: network.ipv6Subnet)
                    }
                    if !network.plugin.isEmpty {
                        KeyValueRow(key: String(localized: "Plugin"), value: network.plugin)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Attached containers")
                    if attached.isEmpty {
                        Text("No containers attached")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text2)
                    } else {
                        ForEach(attached) { container in
                            Button {
                                app.selectedContainer = container
                                app.sidebarItem = .containers
                            } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(container.state.isRunning ? Theme.accent : Theme.text3).frame(width: 7, height: 7)
                                    Text(container.id).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                                    Spacer()
                                    Text(container.ipWithoutMask)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.text2)
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.text3)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Run a container with this network from the Run sheet's Network option; containers on the same network reach each other by name.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete network", systemImage: "trash")
                    }
                    .buttonStyle(BrandButtonStyle(kind: .destructive, fill: true))
                    .disabled(network.isBuiltin || !attached.isEmpty)

                    if network.isBuiltin {
                        Text("Built-in networks can't be deleted.")
                            .font(.caption).foregroundStyle(Theme.text2)
                    } else if !attached.isEmpty {
                        Text("Remove the attached containers before deleting this network.")
                            .font(.caption).foregroundStyle(Theme.text2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(network.name)
        .alert("Delete network \"\(network.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await service.deleteNetwork(network.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct CreateNetworkSheet: View {
    @Binding var isPresented: Bool
    @Environment(ContainerService.self) private var service
    @State private var name = ""
    @State private var subnet = ""
    @State private var isInternal = false
    @State private var isCreating = false
    @State private var error: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create network")
                .font(.headline)

            FormSection("Name") {
                TextField("backend", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await create() } }
            }

            FormSection("Subnet (optional)") {
                TextField("e.g. 192.168.100.0/24", text: $subnet)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            Toggle("Internal (host-only, no outbound access)", isOn: $isInternal)
                .font(.system(size: 12.5))

            if let error {
                ErrorBanner(message: error) { self.error = nil }
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                    .buttonStyle(BrandButtonStyle(kind: .secondary))
                Button("Create") { Task { await create() } }
                    .buttonStyle(BrandButtonStyle(kind: .primary))
                    .disabled(trimmedName.isEmpty || isCreating)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Theme.bg)
    }

    private func create() async {
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        do {
            let s = subnet.trimmingCharacters(in: .whitespaces)
            try await service.createNetwork(trimmedName, subnet: s.isEmpty ? nil : s, internal: isInternal)
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
