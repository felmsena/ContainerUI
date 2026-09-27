import SwiftUI

struct ContainerCardView: View {
    let container: ContainerInfo
    let isSelected: Bool
    @Environment(ContainerService.self) private var service
    @State private var showRemoveAlert = false
    @State private var showKillAlert = false

    /// Same icon and color as the detail header and the Images list. (The
    /// old per-card hue came from `hashValue`, which Swift seeds randomly
    /// per launch, so colors changed every time the app started.)
    private var iconInfo: (symbol: String, color: Color) { imageIcon(for: container.image) }
    private var iconHue: Color { iconInfo.color == .secondary ? Theme.text2 : iconInfo.color }

    private var isPending: Bool { service.pendingContainers.contains(container.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconHue.opacity(0.16))
                        .frame(width: 34, height: 34)
                    Image(systemName: iconInfo.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(iconHue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(container.id)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(container.image)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(spacing: 5) {
                    Circle()
                        .fill(container.state.isRunning ? Theme.accent : Theme.text3)
                        .frame(width: 6, height: 6)
                    Text(container.state.label)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(container.state.isRunning ? Theme.accent : Theme.text3)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (container.state.isRunning ? Theme.accentSoft : Theme.surface2),
                    in: Capsule()
                )
            }

            HStack(spacing: 14) {
                MetaItem(label: "Memory", value: container.memory)
                MetaItem(label: "CPUs", value: "\(container.cpus)")
                MetaItem(label: "Arch", value: container.arch)
                if container.state.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        MetaItem(label: "Uptime", value: container.uptimeDisplay(at: context.date), highlight: true)
                    }
                }
            }

            HStack(spacing: 5) {
                if isPending {
                    ProgressView().controlSize(.small).frame(width: 26, height: 26)
                } else if container.state.isRunning {
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
                Spacer(minLength: 0)
                CardButton(icon: "trash", tooltip: "Remove", destructive: true) {
                    showRemoveAlert = true
                }
                .disabled(isPending)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.accentSoft : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.border,
                            lineWidth: isSelected ? 1.5 : 1
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
    let tooltip: LocalizedStringKey
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(destructive ? Theme.danger : Theme.text2)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(destructive ? Theme.dangerSoft : Theme.surface2)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

struct MetaItem: View {
    let label: LocalizedStringKey
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.text3)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(highlight ? Theme.accent : Theme.text)
        }
    }
}
