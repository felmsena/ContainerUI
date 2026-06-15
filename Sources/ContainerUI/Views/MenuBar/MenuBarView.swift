import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var service: ContainerService

    private var running: [ContainerInfo] {
        service.containers.filter { $0.state.isRunning }
    }
    private var stopped: [ContainerInfo] {
        service.containers.filter { !$0.state.isRunning }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Text("ContainerUI")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                serviceStatusBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Container list
            if service.containers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("No containers")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        if !running.isEmpty {
                            menuSection("Running", containers: running)
                        }
                        if !stopped.isEmpty {
                            menuSection("Stopped", containers: stopped)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            // Footer actions
            VStack(spacing: 2) {
                MenuBarAction(icon: "macwindow", label: "Open ContainerUI") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.identifier?.rawValue == "main-window" {
                        window.makeKeyAndOrderFront(nil)
                    }
                    if NSApp.windows.filter({ $0.isVisible }).isEmpty {
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                }
                MenuBarAction(icon: "arrow.clockwise", label: "Refresh") {
                    Task { await service.fetchContainers() }
                }
                Divider().padding(.vertical, 2)
                MenuBarAction(icon: "power", label: "Quit ContainerUI", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func menuSection(_ title: String, containers: [ContainerInfo]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)

            ForEach(containers) { container in
                MenuBarContainerRow(container: container)
            }
        }
    }

    @ViewBuilder
    private var serviceStatusBadge: some View {
        if service.serviceError != nil {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.orange)
                .font(.system(size: 12))
        } else if service.isLoading {
            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(service.containers.isEmpty ? Color.secondary : Color.green)
                .frame(width: 7, height: 7)
        }
    }
}

struct MenuBarContainerRow: View {
    let container: ContainerInfo
    @EnvironmentObject var service: ContainerService
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(container.state.color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(container.id)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(container.shortImage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if container.state.isRunning {
                Text(container.uptimeDisplay)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    Task { await service.stop(container.id) }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Stop")
            } else {
                Button {
                    Task { await service.start(container.id) }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Start")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .onHover { isHovering = $0 }
    }
}

struct MenuBarAction: View {
    let icon: String
    let label: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
            }
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
