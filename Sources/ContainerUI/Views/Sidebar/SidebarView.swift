import SwiftUI

struct SidebarView: View {
    @Binding var selected: SidebarItem
    @EnvironmentObject var service: ContainerService

    private var runningCount: Int {
        service.containers.filter { $0.state.isRunning }.count
    }

    var body: some View {
        List(SidebarItem.allCases, id: \.self, selection: $selected) { item in
            Label(LocalizedStringKey(item.rawValue), systemImage: item.icon)
                .badge(item == .containers && runningCount > 0 ? runningCount : 0)
        }
        .listStyle(.sidebar)
        .navigationTitle("ContainerUI")
        .toolbar {
            ToolbarItem {
                if service.isLoading && service.daemonState == .running {
                    ProgressView().scaleEffect(0.6)
                }
            }
        }
        .overlay(alignment: .bottom) {
            daemonStatusBanner
        }
    }

    @ViewBuilder
    private var daemonStatusBanner: some View {
        switch service.daemonState {
        case .notInstalled:
            statusBanner(
                icon: "exclamationmark.triangle.fill",
                iconColor: .red,
                message: "Apple Container not installed",
                action: nil
            )
        case .notRunning:
            statusBanner(
                icon: "poweroff",
                iconColor: .orange,
                message: "Service not running",
                action: ("Start", { Task { await service.startDaemon() } })
            )
        case .starting:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.6)
                Text("Starting service…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)
        case .running:
            statusBanner(
                icon: "circle.fill",
                iconColor: .green,
                message: "Service running",
                action: ("Stop", { Task { await service.stopDaemon() } })
            )
        case .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusBanner(icon: String, iconColor: Color, message: LocalizedStringKey, action: (LocalizedStringKey, () -> Void)?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 12))
            Text(message)
                .font(.caption)
                .lineLimit(2)
            if let (label, handler) = action {
                Spacer(minLength: 0)
                Button(label, action: handler)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }
}
