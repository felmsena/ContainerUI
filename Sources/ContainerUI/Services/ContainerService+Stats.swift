import Foundation

extension ContainerService {

    /// Raw counters from one `container stats` sample. `cpuUsageUsec` is
    /// cumulative CPU time since the container started, not a percentage —
    /// CPU% is derived from the delta between two consecutive samples.
    struct RawStatsSample {
        let timestamp: Date
        let cpuUsageUsec: Int
        let memoryUsageBytes: Int
        let memoryLimitBytes: Int
        let networkRxBytes: Int
        let networkTxBytes: Int
    }

    /// Fetches one stats sample for `id` and, once a previous sample exists
    /// to diff against, computes CPU% and appends a point to the container's
    /// rolling 60-sample history. No-ops silently if the CLI call fails
    /// (e.g. the container just stopped).
    func pollStats(for id: String) async {
        guard let output = try? await shell([bin, "stats", "--format", "json", "--no-stream", id]),
              let data = output.data(using: .utf8),
              let raw = Self.parseRawStats(data)
        else { return }

        let now = Date()
        let previous = lastRawStats[id]
        lastRawStats[id] = RawStatsSample(
            timestamp: now, cpuUsageUsec: raw.cpuUsageUsec,
            memoryUsageBytes: raw.memoryUsageBytes, memoryLimitBytes: raw.memoryLimitBytes,
            networkRxBytes: raw.networkRxBytes, networkTxBytes: raw.networkTxBytes
        )

        // The first sample only seeds the delta baseline — there's no
        // meaningful CPU% until a second sample arrives.
        guard let previous else { return }

        let cpuPercent = Self.cpuPercent(
            currentUsec: raw.cpuUsageUsec, previousUsec: previous.cpuUsageUsec,
            currentTime: now, previousTime: previous.timestamp
        )

        latestStats[id] = ContainerStats(
            cpuPercent: cpuPercent,
            memoryUsageBytes: raw.memoryUsageBytes,
            memoryLimitBytes: raw.memoryLimitBytes,
            networkRxBytes: raw.networkRxBytes,
            networkTxBytes: raw.networkTxBytes
        )

        var history = statsHistory[id] ?? []
        history.append(ContainerStatsSample(timestamp: now, cpuPercent: cpuPercent, memoryUsageBytes: raw.memoryUsageBytes))
        if history.count > 60 { history.removeFirst(history.count - 60) }
        statsHistory[id] = history
    }

    /// CPU% between two cumulative `cpuUsageUsec` readings: the fraction of
    /// wall-clock time the container spent on CPU, as a percentage — can
    /// exceed 100% for a container using more than one core. Clamped to 0
    /// so a counter reset (e.g. container restart) never shows negative.
    nonisolated static func cpuPercent(currentUsec: Int, previousUsec: Int, currentTime: Date, previousTime: Date) -> Double {
        let deltaUsec = Double(currentUsec - previousUsec)
        let deltaWallUsec = currentTime.timeIntervalSince(previousTime) * 1_000_000
        guard deltaWallUsec > 0 else { return 0 }
        return max(0, deltaUsec / deltaWallUsec * 100)
    }

    // MARK: – JSON parsing

    private struct StatsEntryJSON: Decodable {
        let cpuUsageUsec: Int
        let memoryUsageBytes: Int
        let memoryLimitBytes: Int
        let networkRxBytes: Int
        let networkTxBytes: Int
    }

    nonisolated static func parseRawStats(_ data: Data) -> (
        cpuUsageUsec: Int, memoryUsageBytes: Int, memoryLimitBytes: Int,
        networkRxBytes: Int, networkTxBytes: Int
    )? {
        guard let entries = try? JSONDecoder().decode([StatsEntryJSON].self, from: data),
              let entry = entries.first
        else { return nil }
        return (entry.cpuUsageUsec, entry.memoryUsageBytes, entry.memoryLimitBytes,
                entry.networkRxBytes, entry.networkTxBytes)
    }
}
