import SwiftUI

enum SidebarSection: String, CaseIterable {
    case manage
    case explore
    case monitor

    var title: LocalizedStringKey {
        switch self {
        case .manage: return "Manage"
        case .explore: return "Explore"
        case .monitor: return "Monitor"
        }
    }

    var items: [SidebarItem] {
        switch self {
        case .manage: return [.containers, .images, .volumes]
        case .explore: return [.registry, .build, .groups]
        case .monitor: return [.stats, .logs]
        }
    }
}

extension SidebarItem {
    /// Accent hue used for the item's icon badge, matching the mockup's per-item colors.
    var badgeHue: Color {
        switch self {
        case .containers: return Theme.accent
        case .images: return Color(hex: "#3B82F6")
        case .volumes: return Color(hex: "#D97706")
        case .registry: return Color(hex: "#7C6FE0")
        case .build: return Color(hex: "#E2596B")
        case .groups: return Color(hex: "#14B8A6")
        case .stats: return Theme.accent
        case .logs: return Color(hex: "#64748B")
        case .settings: return Color(hex: "#889098")
        }
    }
}

struct SidebarView: View {
    @Binding var selected: SidebarItem
    @EnvironmentObject var service: ContainerService

    private var runningCount: Int {
        service.containers.filter { $0.state.isRunning }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                    sectionHeader(section.title)
                        .padding(.top, index == 0 ? 4 : 12)
                    ForEach(section.items, id: \.self) { item in
                        row(for: item)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .background(Theme.surface)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                row(for: .settings)
                daemonStatusCard
            }
            .padding(.bottom, 6)
            .background(Theme.surface)
        }
        .navigationTitle("ContainerUI")
        .toolbar {
            ToolbarItem {
                if service.isLoading && service.daemonState == .running {
                    ProgressView().scaleEffect(0.6)
                }
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.text3)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
    }

    private func row(for item: SidebarItem) -> some View {
        let isSelected = selected == item
        return Button {
            selected = item
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.badgeHue.opacity(0.16))
                        .frame(width: 26, height: 26)
                    Image(systemName: item.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.badgeHue)
                }
                Text(LocalizedStringKey(item.rawValue))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                if item == .containers && runningCount > 0 {
                    Text("\(runningCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Theme.accentStrong, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.accentSoft : Color.clear)
            )
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 3)
    }

    @ViewBuilder
    private var daemonStatusCard: some View {
        switch service.daemonState {
        case .notInstalled:
            statusCard(
                dotColor: Theme.danger,
                title: "Apple Container not installed",
                subtitle: "Install it to get started",
                action: nil
            )
        case .notRunning:
            statusCard(
                dotColor: Theme.warn,
                title: "Service not running",
                subtitle: "Start it to manage containers",
                action: ("Start", { Task { await service.startDaemon() } })
            )
        case .starting:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.6)
                Text("Starting service…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text2)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 10)
        case .running:
            statusCard(
                dotColor: Theme.accent,
                title: "Service running",
                subtitle: "Apple Container is active",
                action: ("Stop", { Task { await service.stopDaemon() } })
            )
        case .unknown:
            EmptyView()
        }
    }

    private func statusCard(dotColor: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey, action: (LocalizedStringKey, () -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(2)
            }
            if let (label, handler) = action {
                Spacer(minLength: 0)
                Button(label, action: handler)
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(11)
        .background(dotColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dotColor.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 10)
    }
}
