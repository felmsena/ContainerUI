import SwiftUI
import Charts

struct StatsTabView: View {
    let container: ContainerInfo
    @EnvironmentObject var service: ContainerService

    private var stats: ContainerStats? { service.latestStats[container.id] }
    private var history: [ContainerStatsSample] { service.statsHistory[container.id] ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let stats {
                    LazyVStack(spacing: 12) {
                        StatCard(label: "CPU Usage", value: String(format: "%.1f%%", stats.cpuPercent), icon: "cpu")
                        StatCard(label: "Memory", value: "\(formatBytes(stats.memoryUsageBytes)) / \(formatBytes(stats.memoryLimitBytes))", icon: "memorychip")
                        StatCard(label: "Net In", value: formatBytes(stats.networkRxBytes), icon: "arrow.down.circle")
                        StatCard(label: "Net Out", value: formatBytes(stats.networkTxBytes), icon: "arrow.up.circle")
                    }

                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CPU % (last 2 min)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Chart(history) { sample in
                                    LineMark(
                                        x: .value("Time", sample.timestamp),
                                        y: .value("CPU %", sample.cpuPercent)
                                    )
                                    .foregroundStyle(.blue)
                                    .interpolationMethod(.catmullRom)
                                }
                                .frame(height: 90)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Memory (last 2 min)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Chart(history) { sample in
                                    AreaMark(
                                        x: .value("Time", sample.timestamp),
                                        y: .value("Memory", sample.memoryUsageBytes)
                                    )
                                    .foregroundStyle(.green.opacity(0.25))
                                    LineMark(
                                        x: .value("Time", sample.timestamp),
                                        y: .value("Memory", sample.memoryUsageBytes)
                                    )
                                    .foregroundStyle(.green)
                                }
                                .frame(height: 90)
                            }
                        }
                    }
                } else if container.state.isRunning {
                    ProgressView("Loading stats…")
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(.quaternary)
                        Text("Container is not running")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                Divider().padding(.top, 4)

                // Static info always visible
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocated Resources")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    StatCard(label: "Memory limit", value: container.memory, icon: "memorychip")
                    StatCard(label: "CPUs", value: "\(container.cpus)", icon: "cpu")
                    StatCard(label: "Architecture", value: container.arch, icon: "cpu.fill")
                }
            }
            .padding(12)
        }
        .task(id: container.id) {
            guard container.state.isRunning else { return }
            while !Task.isCancelled {
                await service.pollStats(for: container.id)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}

struct StatCard: View {
    let label: LocalizedStringKey
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        )
    }
}
