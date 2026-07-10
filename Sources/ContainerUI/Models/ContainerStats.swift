import Foundation

/// Latest instantaneous resource snapshot for a container, shown above the
/// history charts in StatsTabView.
struct ContainerStats {
    let cpuPercent: Double
    let memoryUsageBytes: Int
    let memoryLimitBytes: Int
    let networkRxBytes: Int
    let networkTxBytes: Int
}

/// One point in a container's rolling CPU%/memory history, driving the
/// Swift Charts views in StatsTabView.
struct ContainerStatsSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuPercent: Double
    let memoryUsageBytes: Int
}
