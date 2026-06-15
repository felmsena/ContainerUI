import SwiftUI

struct InfoTabView: View {
    let container: ContainerInfo
    @EnvironmentObject var service: ContainerService
    @State private var customPort = ""
    @State private var copiedKey: String?

    private var rows: [(String, String)] {
        [
            ("ID",      container.id),
            ("Image",   container.image),
            ("OS",      "\(container.os) / \(container.arch)"),
            ("State",   container.state.label),
            ("IP",      container.ip.isEmpty ? "—" : container.ip),
            ("CPUs",    "\(container.cpus)"),
            ("Memory",  container.memory),
            ("Uptime",  container.state.isRunning ? container.uptimeDisplay : "—"),
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
            VStack(alignment: .leading, spacing: 0) {

                // Info rows
                ForEach(rows, id: \.0) { key, value in
                    HStack(alignment: .center, spacing: 8) {
                        Text(key)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text(value)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                        if key == "ID" || key == "IP" {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(value, forType: .string)
                                copiedKey = key
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = nil }
                            } label: {
                                Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundStyle(copiedKey == key ? Color.green : Color(nsColor: .tertiaryLabelColor))
                            }
                            .buttonStyle(.plain)
                            .help("Copy \(key)")
                            .disabled(value == "—")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    Divider().padding(.leading, 12)
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
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 8) {
                            Button {
                                Task { await service.restart(container.id) }
                            } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                Task { await service.stop(container.id) }
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }

                    } else {
                        Button {
                            Task { await service.start(container.id) }
                        } label: {
                            Label("Start container", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(12)
            }
        }
    }

    private func openCustomPort() {
        guard let port = Int(customPort) else { return }
        service.openInBrowser(ip: container.ipWithoutMask, port: port)
    }
}

