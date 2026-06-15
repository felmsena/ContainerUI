import Foundation

extension ContainerService {

    func fetchVolumes() async {
        let output = (try? await shell("\(bin) volume ls")) ?? ""
        volumes = Self.parseVolumeList(output)
    }

    func createVolume(_ name: String) async throws {
        try await shell("\(bin) volume create \(name)")
        await fetchVolumes()
    }

    func deleteVolume(_ name: String) async {
        _ = try? await shell("\(bin) volume rm \(name)")
        await fetchVolumes()
    }

    func pruneVolumes() async {
        _ = try? await shell("\(bin) volume prune")
        await fetchVolumes()
    }

    static func parseVolumeList(_ output: String) -> [VolumeInfo] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let nameOff    = columnOffset("NAME",    in: header),
            let typeOff    = columnOffset("TYPE",    in: header),
            let driverOff  = columnOffset("DRIVER",  in: header),
            let optionsOff = columnOffset("OPTIONS", in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > nameOff else { return nil }
            let name    = field(chars, from: nameOff,    to: typeOff)
            let type    = field(chars, from: typeOff,    to: driverOff)
            let driver  = field(chars, from: driverOff,  to: optionsOff)
            let options = field(chars, from: optionsOff, to: nil)
            guard !name.isEmpty else { return nil }
            return VolumeInfo(name: name, type: type, driver: driver, options: options)
        }
    }
}
