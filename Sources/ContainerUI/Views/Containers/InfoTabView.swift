import SwiftUI

struct InfoTabView: View {
    let container: ContainerInfo
    @Environment(ContainerService.self) private var service
    @AppStorage("defaultBrowserPort") private var defaultPort = "9000"
    @State private var customPort = ""
    @State private var copiedKey: String?
    @State private var detail: ContainerDetail?

    /// `key` is a stable, non-localized identifier used for copy-button logic;
    /// `label` is the localized display text.
    private func rows(at now: Date) -> [(key: String, label: String, value: String)] {
        [
            ("ID",     String(localized: "ID"),     container.id),
            ("Image",  String(localized: "Image"),  container.image),
            ("OS",     String(localized: "OS"),      "\(container.os) / \(container.arch)"),
            ("State",  String(localized: "State"),  container.state.label),
            ("IP",     String(localized: "IP"),     container.ip.isEmpty ? "—" : container.ip),
            ("CPUs",   String(localized: "CPUs"),   "\(container.cpus)"),
            ("Memory", String(localized: "Memory"), container.memory),
            ("Uptime", String(localized: "Uptime"), container.state.isRunning ? container.uptimeDisplay(at: now) : "—"),
        ]
    }

    private struct BrowserTarget: Identifiable {
        var id: Int { containerPort }
        let containerPort: Int
        let label: String
        let url: URL
    }

    /// Ports worth a one-click "open": every published port first (reached
    /// through its host mapping), then the image's usual ports, reached
    /// directly on the container's IP.
    private var browserTargets: [BrowserTarget] {
        let published = detail?.ports ?? []
        var targets: [BrowserTarget] = published.compactMap { p in
            ContainerService.browserURL(containerPort: p.containerPort, ip: container.ipWithoutMask, published: published)
                .map { BrowserTarget(containerPort: p.containerPort, label: "→ :\(p.hostPort)", url: $0) }
        }
        for known in ImageKnowledge.hint(for: container.image)?.ports ?? [] where !targets.contains(where: { $0.containerPort == known.port }) {
            if let url = ContainerService.browserURL(containerPort: known.port, ip: container.ipWithoutMask, published: published) {
                targets.append(BrowserTarget(containerPort: known.port, label: known.label, url: url))
            }
        }
        return targets
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Info rows
                TimelineView(.periodic(from: .now, by: 1)) { context in
                SectionCard(title: "Overview") {
                    ForEach(Array(rows(at: context.date).enumerated()), id: \.element.key) { index, row in
                        if index > 0 { Divider() }
                        HStack(alignment: .center, spacing: 8) {
                            Text(row.label)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.text2)
                                .frame(width: 64, alignment: .leading)
                            Text(row.value)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .multilineTextAlignment(.trailing)
                            if row.key == "ID" || row.key == "IP" {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(row.value, forType: .string)
                                    copiedKey = row.key
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = nil }
                                } label: {
                                    Image(systemName: copiedKey == row.key ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundStyle(copiedKey == row.key ? Theme.accent : Theme.text3)
                                }
                                .buttonStyle(.plain)
                                .help(LocalizedStringKey("Copy \(row.label)"))
                                .accessibilityLabel(copiedKey == row.key ? "Copied" : LocalizedStringKey("Copy \(row.label)"))
                                .disabled(row.value == "—")
                            }
                        }
                    }
                }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Inspect detail (mounts / env / ports / resources)
                if let detail {
                    VStack(alignment: .leading, spacing: 12) {
                        if !detail.mounts.isEmpty {
                            SectionCard(title: "Mounts") {
                                ForEach(Array(detail.mounts.enumerated()), id: \.element.id) { index, mount in
                                    if index > 0 { Divider() }
                                    KeyValueRow(key: mount.destination, value: mount.source)
                                }
                            }
                        }

                        if !detail.environment.isEmpty {
                            SectionCard(title: "Environment") {
                                ForEach(Array(detail.environment.enumerated()), id: \.offset) { index, entry in
                                    if index > 0 { Divider() }
                                    let parts = entry.split(separator: "=", maxSplits: 1)
                                    KeyValueRow(key: String(parts.first ?? ""),
                                                value: parts.count > 1 ? String(parts[1]) : "")
                                }
                            }
                        }

                        if !detail.ports.isEmpty {
                            SectionCard(title: "Ports") {
                                ForEach(Array(detail.ports.enumerated()), id: \.element.id) { index, port in
                                    if index > 0 { Divider() }
                                    KeyValueRow(key: "\(port.containerPort)/\(port.proto)",
                                                value: "\(port.hostAddress):\(port.hostPort)")
                                }
                            }
                        }

                        SectionCard(title: "Resources") {
                            KeyValueRow(key: String(localized: "CPUs"), value: "\(detail.cpus)")
                            Divider()
                            KeyValueRow(key: String(localized: "Memory"), value: formatBytes(detail.memoryInBytes))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 10) {
                    if service.pendingContainers.contains(container.id) {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Working…").font(.system(size: 12)).foregroundStyle(Theme.text2)
                        }
                    }
                    if container.state.isRunning {

                        // Ports to open in the browser
                        if !browserTargets.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Open in browser")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text2)
                                FlowLayout(spacing: 6) {
                                    ForEach(browserTargets) { target in
                                        Button {
                                            NSWorkspace.shared.open(target.url)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "safari")
                                                    .font(.system(size: 10))
                                                Text(":\(target.containerPort)")
                                                    .font(.system(size: 11, design: .monospaced))
                                                Text("·")
                                                    .foregroundStyle(Theme.text3)
                                                Text(target.label)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Theme.text2)
                                            }
                                        }
                                        .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                                        .help(target.url.absoluteString)
                                    }
                                }
                            }
                        }

                        // Custom port
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField("Custom port…", text: $customPort)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 90)
                                .onSubmit { openCustomPort() }
                            Button("Open", action: openCustomPort)
                                .buttonStyle(BrandButtonStyle(kind: .secondary, compact: true))
                                .disabled(Int(customPort) == nil)
                        }

                        Divider()

                        // Shell + controls
                        Button {
                            service.openShell(for: container.id)
                        } label: {
                            Label("Open shell", systemImage: "terminal")
                        }
                        .buttonStyle(BrandButtonStyle(kind: .secondary, fill: true))

                        HStack(spacing: 8) {
                            Button {
                                Task { await service.restart(container.id) }
                            } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BrandButtonStyle(kind: .secondary, fill: true))

                            Button(role: .destructive) {
                                Task { await service.stop(container.id) }
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(BrandButtonStyle(kind: .destructive, fill: true))
                        }

                    } else {
                        Button {
                            Task { await service.start(container.id) }
                        } label: {
                            Label("Start container", systemImage: "play.fill")
                        }
                        .buttonStyle(BrandButtonStyle(kind: .primary, fill: true))
                    }
                }
                .padding(12)
                .disabled(service.pendingContainers.contains(container.id))
            }
        }
        // Re-inspect when the state changes: published ports and resources
        // are only meaningful for the current run.
        .task(id: container.state) { detail = await service.inspectContainer(container.id) }
        .onAppear { if customPort.isEmpty { customPort = defaultPort } }
    }

    private func openCustomPort() {
        guard let port = Int(customPort),
              let url = ContainerService.browserURL(containerPort: port, ip: container.ipWithoutMask, published: detail?.ports ?? [])
        else { return }
        NSWorkspace.shared.open(url)
    }
}

