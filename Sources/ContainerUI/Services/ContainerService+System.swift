import Foundation

extension ContainerService {

    func fetchSystemInfo() async {
        async let statusJSONOut = try? shell([bin, "system", "status", "--format", "json"])
        async let dfRows        = try? fetchJSONOrText(
            args: [bin, "system", "df"],
            jsonParse: Self.parseSystemDfJSON,
            textParse: Self.parseSystemDf
        )
        async let versionRowsOut = try? fetchJSONOrText(
            args: [bin, "system", "version"],
            jsonParse: Self.parseVersionRowsJSON,
            textParse: Self.parseVersionRows
        )

        let (s, d, v) = await (statusJSONOut, dfRows, versionRowsOut)

        if let s, let data = s.data(using: .utf8), let parsed = Self.parseSystemStatusJSON(data) {
            systemStatus = parsed
        } else {
            let textOut = (try? await shell([bin, "system", "status"])) ?? ""
            systemStatus = Self.parseSystemStatus(textOut)
        }
        systemDf    = d ?? []
        versionRows = v ?? []
    }

    func fetchSystemLogs() async -> String {
        (try? await shell([bin, "system", "logs"])) ?? ""
    }

    func startService() async {
        _ = try? await shell([bin, "system", "start"])
        await fetchSystemInfo()
        await fetchContainers()
    }

    func stopService() async {
        _ = try? await shell([bin, "system", "stop"])
        await fetchSystemInfo()
        await fetchContainers()
    }

    nonisolated static func parseSystemStatus(_ output: String) -> SystemStatusInfo? {
        var values: [String: String] = [:]
        for line in output.components(separatedBy: "\n").dropFirst() where !line.isEmpty {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            values[parts[0]] = parts[1...].joined(separator: " ")
        }
        guard let status = values["status"] else { return nil }
        return SystemStatusInfo(
            status:           status,
            appRoot:          values["appRoot"] ?? "",
            installRoot:      values["installRoot"] ?? "",
            apiserverVersion: values["apiserver.version"] ?? ""
        )
    }

    nonisolated static func parseSystemDf(_ output: String) -> [SystemDfRow] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let typeOff        = columnOffset("TYPE",        in: header),
            let totalOff       = columnOffset("TOTAL",       in: header),
            let activeOff      = columnOffset("ACTIVE",      in: header),
            let sizeOff        = columnOffset("SIZE",        in: header),
            let reclaimOff     = columnOffset("RECLAIMABLE", in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > typeOff else { return nil }
            let type       = field(chars, from: typeOff,    to: totalOff)
            let total      = field(chars, from: totalOff,   to: activeOff)
            let active     = field(chars, from: activeOff,  to: sizeOff)
            let size       = field(chars, from: sizeOff,    to: reclaimOff)
            let reclaimable = field(chars, from: reclaimOff, to: nil)
            guard !type.isEmpty else { return nil }
            return SystemDfRow(type: type, total: total, active: active,
                               size: size, reclaimable: reclaimable)
        }
    }

    nonisolated static func parseVersionRows(_ output: String) -> [VersionRow] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let compOff    = columnOffset("COMPONENT", in: header),
            let verOff     = columnOffset("VERSION",   in: header),
            let buildOff   = columnOffset("BUILD",     in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > compOff else { return nil }
            let comp  = field(chars, from: compOff,  to: verOff)
            let ver   = field(chars, from: verOff,   to: buildOff)
            let build = field(chars, from: buildOff, to: nil)
            guard !comp.isEmpty else { return nil }
            return VersionRow(component: comp, version: ver, build: build)
        }
    }

    // MARK: – JSON parsing

    private struct SystemStatusJSON: Decodable {
        let status: String
        let appRoot: String
        let installRoot: String
        let apiServerVersion: String
    }

    nonisolated static func parseSystemStatusJSON(_ data: Data) -> SystemStatusInfo? {
        guard let s = try? JSONDecoder().decode(SystemStatusJSON.self, from: data) else { return nil }
        return SystemStatusInfo(status: s.status, appRoot: s.appRoot,
                                 installRoot: s.installRoot, apiserverVersion: s.apiServerVersion)
    }

    private struct SystemDfJSON: Decodable {
        struct Category: Decodable { let total: Int; let active: Int; let sizeInBytes: Int; let reclaimable: Int }
        let images: Category
        let containers: Category
        let volumes: Category
    }

    nonisolated private static func reclaimableDisplay(_ reclaimable: Int, of total: Int) -> String {
        guard total > 0 else { return formatBytes(reclaimable) }
        let pct = Int((Double(reclaimable) / Double(total) * 100).rounded())
        return "\(formatBytes(reclaimable)) (\(pct)%)"
    }

    nonisolated static func parseSystemDfJSON(_ data: Data) -> [SystemDfRow]? {
        guard let df = try? JSONDecoder().decode(SystemDfJSON.self, from: data) else { return nil }
        func row(_ type: String, _ c: SystemDfJSON.Category) -> SystemDfRow {
            SystemDfRow(
                type: type,
                total: "\(c.total)",
                active: "\(c.active)",
                size: formatBytes(c.sizeInBytes),
                reclaimable: reclaimableDisplay(c.reclaimable, of: c.sizeInBytes)
            )
        }
        return [
            row("Images", df.images),
            row("Containers", df.containers),
            row("Local Volumes", df.volumes)
        ]
    }

    private struct VersionRowJSON: Decodable {
        let appName: String
        let version: String
        let buildType: String
    }

    nonisolated static func parseVersionRowsJSON(_ data: Data) -> [VersionRow]? {
        guard let entries = try? JSONDecoder().decode([VersionRowJSON].self, from: data) else { return nil }
        return entries.map { VersionRow(component: $0.appName, version: $0.version, build: $0.buildType) }
    }
}
