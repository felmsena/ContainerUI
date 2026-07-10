import SwiftUI

struct ContainerCardView: View {
    let container: ContainerInfo
    let isSelected: Bool
    @EnvironmentObject var service: ContainerService
    @State private var showRemoveAlert = false
    @State private var showKillAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(container.state.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(container.id)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(container.image)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 5) {
                    if container.state.isRunning {
                        CardButton(icon: "terminal", tooltip: "Open shell") {
                            service.openShell(for: container.id)
                        }
                        CardButton(icon: "stop.fill", tooltip: "Stop") {
                            Task { await service.stop(container.id) }
                        }
                        CardButton(icon: "arrow.clockwise", tooltip: "Restart") {
                            Task { await service.restart(container.id) }
                        }
                    } else {
                        CardButton(icon: "play.fill", tooltip: "Start") {
                            Task { await service.start(container.id) }
                        }
                    }
                    CardButton(icon: "trash", tooltip: "Remove", destructive: true) {
                        showRemoveAlert = true
                    }
                }
            }

            HStack(spacing: 16) {
                if !container.ipWithoutMask.isEmpty {
                    MetaItem(label: "IP", value: container.ipWithoutMask)
                }
                MetaItem(label: "Memory", value: container.memory)
                MetaItem(label: "CPUs", value: "\(container.cpus)")
                MetaItem(label: "Arch", value: container.arch)
                if container.state.isRunning {
                    MetaItem(label: "Uptime", value: container.uptimeDisplay, highlight: true)
                } else {
                    MetaItem(label: "State", value: container.state.label)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.green : Color(nsColor: .separatorColor),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
        .contextMenu {
            if container.state.isRunning {
                Button {
                    service.openShell(for: container.id)
                } label: {
                    Label("Open shell", systemImage: "terminal")
                }
                Button {
                    Task { await service.restart(container.id) }
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await service.stop(container.id) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                Button(role: .destructive) {
                    showKillAlert = true
                } label: {
                    Label("Kill", systemImage: "bolt.fill")
                }
            } else {
                Button {
                    Task { await service.start(container.id) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
            }
            Divider()
            Button(role: .destructive) {
                showRemoveAlert = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .alert("Remove \"\(container.id)\"?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) {
                Task { await service.remove(container.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Kill \"\(container.id)\"?", isPresented: $showKillAlert) {
            Button("Kill", role: .destructive) {
                Task { await service.kill(container.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Kill sends SIGKILL immediately.")
        }
    }
}

struct CardButton: View {
    let icon: String
    let tooltip: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(destructive ? Color.red : Color.secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct MetaItem: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(highlight ? .green : .primary)
        }
    }
}
