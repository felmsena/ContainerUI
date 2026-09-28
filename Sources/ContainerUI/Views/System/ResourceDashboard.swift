import SwiftUI

/// Live CPU and memory across all running containers, polled with a single
/// `container stats` call every 3 s while the Stats section is visible.
struct ResourceDashboard: View {
    @Environment(ContainerService.self) private var service
    @Environment(AppState.self) private var app

    private var running: [ContainerInfo] { service.containers.filter { $0.state.isRunning } }

    private var rows: [(container: ContainerInfo, stats: ContainerStats)] {
        running.compactMap { c in service.latestStats[c.id].map { (c, $0) } }
            .sorted { $0.stats.cpuPercent > $1.stats.cpuPercent }
    }

    var body: some View {
        let rows = self.rows
        let totalCPU = rows.reduce(0) { $0 + $1.stats.cpuPercent }
        let totalMem = rows.reduce(0) { $0 + $1.stats.memoryUsageBytes }
        let totalLimit = rows.reduce(0) { $0 + $1.stats.memoryLimitBytes }
        let hostCPUs = service.systemStatus?.hostCPUs

        SectionCard(title: "Resources") {
            HStack(spacing: 12) {
                tile(label: "Running", value: "\(running.count)", icon: "square.stack.3d.up")
                tile(label: "CPU", value: String(format: "%.1f%%", totalCPU), icon: "cpu",
                     detail: hostCPUs.map { String(localized: "\($0) host cores") })
                tile(label: "Memory", value: formatBytes(totalMem), icon: "memorychip",
                     detail: totalLimit > 0 ? String(localized: "of \(formatBytes(totalLimit)) allocated") : nil)
            }

            if running.isEmpty {
                Text("No containers running.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
            } else if rows.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Measuring…").font(.system(size: 12)).foregroundStyle(Theme.text2)
                }
            } else {
                Divider()
                ForEach(rows, id: \.container.id) { row in
                    Button {
                        app.selectedContainer = row.container
                        app.sidebarItem = .containers
                    } label: {
                        usageRow(row.container, row.stats, hostCPUs: hostCPUs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                await service.pollAllStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func tile(label: LocalizedStringKey, value: String, icon: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            if let detail {
                Text(detail).font(.system(size: 10.5)).foregroundStyle(Theme.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
    }

    private func usageRow(_ c: ContainerInfo, _ s: ContainerStats, hostCPUs: Int?) -> some View {
        // CPU bar relative to the container's own CPUs (100% per core).
        let cpuCap = Double(max(c.cpus, 1)) * 100
        let memFraction = s.memoryLimitBytes > 0 ? Double(s.memoryUsageBytes) / Double(s.memoryLimitBytes) : 0
        return HStack(spacing: 10) {
            Text(c.id)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)
            meter(fraction: s.cpuPercent / cpuCap, label: String(format: "%.1f%%", s.cpuPercent), color: Theme.accent)
            meter(fraction: memFraction, label: formatBytes(s.memoryUsageBytes), color: Theme.Hue.blue)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func meter(fraction: Double, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule().fill(color).frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 6)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text2)
                .frame(width: 70, alignment: .trailing)
        }
    }
}
