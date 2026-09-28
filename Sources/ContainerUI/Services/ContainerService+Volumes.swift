import Foundation

extension ContainerService {

    /// Containers that mount `volume`: by volume name, or (for older CLIs
    /// without typed mounts) by the volume's backing image path.
    func containers(using volume: VolumeInfo) -> [ContainerInfo] {
        containers.filter {
            $0.volumeNames.contains(volume.name) || (!volume.source.isEmpty && $0.mountSources.contains(volume.source))
        }
    }

    func fetchVolumes() async {
        update(\.volumes, (try? await fetchJSONOrText(
            args: [bin] + CLI.volumeList(),
            jsonParse: Self.parseVolumeListJSON,
            textParse: Self.parseVolumeList
        )) ?? [])
    }

    func createVolume(_ name: String) async throws {
        try await cli(CLI.volumeCreate(name))
        await fetchVolumes()
    }

    func deleteVolume(_ name: String) async {
        do { try await cli(CLI.volumeDelete(name)) } catch { report(error, as: String(localized: "Couldn't delete volume \(name)")) }
        await fetchVolumes()
    }

    func pruneVolumes() async {
        do { try await cli(CLI.volumePrune()) } catch { report(error, as: String(localized: "Couldn't prune volumes")) }
        await fetchVolumes()
    }

    nonisolated static func parseVolumeList(_ output: String) -> [VolumeInfo] {
        tableRows(output, columns: ["NAME", "TYPE", "DRIVER", "OPTIONS"]).map { f in
            VolumeInfo(name: f[0], type: f[1], driver: f[2], options: f[3])
        }
    }

    // MARK: – JSON parsing

    private struct VolumeListEntryJSON: Decodable {
        struct Configuration: Decodable {
            let name: String
            let driver: String
            let options: [String: String]?
            let source: String?
            let sizeInBytes: Int?
        }
        let configuration: Configuration
    }

    nonisolated static func parseVolumeListJSON(_ data: Data) -> [VolumeInfo]? {
        guard let entries = try? JSONDecoder().decode([VolumeListEntryJSON].self, from: data) else { return nil }
        return entries.map { entry in
            let options = (entry.configuration.options ?? [:])
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",")
            return VolumeInfo(name: entry.configuration.name, type: "named",
                               driver: entry.configuration.driver, options: options,
                               source: entry.configuration.source ?? "",
                               sizeInBytes: entry.configuration.sizeInBytes)
        }
    }
}
