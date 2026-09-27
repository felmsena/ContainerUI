import SwiftUI

struct InfoTabView: View {
    let container: ContainerInfo
    @Environment(ContainerService.self) private var service
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

    private var knownPorts: [(port: Int, label: String)] {
        let lower = container.image.lowercased()
        if lower.contains("nginx") || lower.contains("caddy") || lower.contains("apache") {
            return [(80, "HTTP"), (443, "HTTPS")]
        }
        if lower.contains("postgres")                { return [(5432, "PostgreSQL")] }
        if lower.contains("mysql") || lower.contains("mariadb") { return [(3306, "MySQL")] }
        if lower.contains("mongo")                   { return [(27017, "MongoDB")] }
        if lower.contains("redis")                   { return [(6379, "Redis")] }
        if lower.contains("elastic")                 { return [(9200, "HTTP"), (9300, "Transport")] }
        if lower.contains("kibana")                  { return [(5601, "Kibana")] }
        if lower.contains("grafana")                 { return [(3000, "Grafana")] }
        if lower.contains("sonar")                   { return [(9000, "SonarQube")] }
        if lower.contains("jenkins")                 { return [(8080, "HTTP"), (50000, "Agent")] }
        if lower.contains("gitlab")                  { return [(80, "HTTP"), (443, "HTTPS"), (22, "SSH")] }
        if lower.contains("minio")                   { return [(9000, "API"), (9001, "Console")] }
        if lower.contains("rabbit")                  { return [(5672, "AMQP"), (15672, "Management")] }
        if lower.contains("kafka")                   { return [(9092, "Broker")] }
        if lower.contains("node") || lower.contains("express") || lower.contains("next") {
            return [(3000, "HTTP")]
        }
        if lower.contains("wordpress") || lower.contains("ghost") { return [(80, "HTTP")] }
        if lower.contains("prometheus")              { return [(9090, "HTTP")] }
        if lower.contains("traefik")                 { return [(80, "HTTP"), (8080, "Dashboard")] }
        return []
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
                    if container.state.isRunning {

                        // Known ports
                        if !knownPorts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Open in browser")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                FlowLayout(spacing: 6) {
                                    ForEach(knownPorts, id: \.port) { item in
                                        Button {
                                            service.openInBrowser(ip: container.ipWithoutMask, port: item.port)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "safari")
                                                    .font(.system(size: 10))
                                                Text(":\(item.port)")
                                                    .font(.system(size: 11, design: .monospaced))
                                                Text("·")
                                                    .foregroundStyle(.tertiary)
                                                Text(item.label)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
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
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
            }
        }
        .task { detail = await service.inspectContainer(container.id) }
    }

    private func openCustomPort() {
        guard let port = Int(customPort) else { return }
        service.openInBrowser(ip: container.ipWithoutMask, port: port)
    }
}

