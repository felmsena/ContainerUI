import Foundation

extension ContainerService {

    func fetchNetworks() async {
        update(\.networks, (try? await fetchJSONOrText(
            args: [bin] + CLI.networkList(),
            jsonParse: Self.parseNetworkListJSON,
            textParse: Self.parseNetworkList
        )) ?? [])
    }

    func createNetwork(_ name: String, subnet: String?, internal: Bool) async throws {
        try await cli(CLI.networkCreate(name, subnet: subnet, internal: `internal`))
        await fetchNetworks()
    }

    func deleteNetwork(_ name: String) async {
        do { try await cli(CLI.networkDelete(name)) } catch { report(error, as: String(localized: "Couldn't delete network \(name)")) }
        await fetchNetworks()
    }

    func pruneNetworks() async {
        do { try await cli(CLI.networkPrune()) } catch { report(error, as: String(localized: "Couldn't prune networks")) }
        await fetchNetworks()
    }

    func containers(on network: NetworkInfo) -> [ContainerInfo] {
        containers.filter { $0.networks.contains(network.name) }
    }

    // MARK: – Parsing

    nonisolated static func parseNetworkList(_ output: String) -> [NetworkInfo] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1,
              let nameOff = columnOffset("NETWORK", in: lines[0])
        else { return [] }
        let subnetOff = columnOffset("SUBNET", in: lines[0])
        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            let name = field(chars, from: nameOff, to: subnetOff)
            guard !name.isEmpty else { return nil }
            let subnet = subnetOff.map { field(chars, from: $0, to: nil) } ?? ""
            return NetworkInfo(name: name, subnet: subnet)
        }
    }

    private struct NetworkEntryJSON: Decodable {
        struct Configuration: Decodable {
            let name: String?
            let mode: String?
            let plugin: String?
            let labels: [String: String]?
        }
        struct Status: Decodable {
            let ipv4Subnet: String?
            let ipv4Gateway: String?
            let ipv6Subnet: String?
        }
        let id: String
        let configuration: Configuration?
        let status: Status?
    }

    nonisolated static func parseNetworkListJSON(_ data: Data) -> [NetworkInfo]? {
        guard let entries = try? JSONDecoder().decode([NetworkEntryJSON].self, from: data) else { return nil }
        return entries.map { e in
            NetworkInfo(
                name: e.configuration?.name ?? e.id,
                mode: e.configuration?.mode ?? "",
                subnet: e.status?.ipv4Subnet ?? "",
                gateway: e.status?.ipv4Gateway ?? "",
                ipv6Subnet: e.status?.ipv6Subnet ?? "",
                plugin: e.configuration?.plugin ?? "",
                labels: e.configuration?.labels ?? [:]
            )
        }
    }
}
