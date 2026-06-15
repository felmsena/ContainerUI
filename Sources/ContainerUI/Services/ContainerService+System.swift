import Foundation

extension ContainerService {

    func fetchSystemInfo() async {
        async let statusOut  = try? shell("\(bin) system status")
        async let dfOut      = try? shell("\(bin) system df")
        async let versionOut = try? shell("\(bin) system version")

        let (s, d, v) = await (statusOut, dfOut, versionOut)
        systemStatus = Self.parseSystemStatus(s ?? "")
        systemDf     = Self.parseSystemDf(d ?? "")
        versionRows  = Self.parseVersionRows(v ?? "")
    }

    func fetchSystemLogs() async -> String {
        (try? await shell("\(bin) system logs")) ?? ""
    }

    func startService() async {
        _ = try? await shell("\(bin) system start")
        await fetchSystemInfo()
        await fetchContainers()
    }

    func stopService() async {
        _ = try? await shell("\(bin) system stop")
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
}
