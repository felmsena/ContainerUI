import Foundation

extension ContainerService {

    func fetchImages() async {
        let output = (try? await shell("\(bin) image ls")) ?? ""
        images = Self.parseImageList(output)
    }

    func pullImage(_ ref: String) async throws {
        try await shell("\(bin) image pull \(ref)")
        await fetchImages()
    }

    func deleteImage(_ ref: String) async {
        _ = try? await shell("\(bin) image rm \(ref)")
        await fetchImages()
    }

    func pruneImages() async {
        _ = try? await shell("\(bin) image prune")
        await fetchImages()
    }

    nonisolated static func parseImageList(_ output: String) -> [ImageInfo] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0]
        guard
            let nameOff   = columnOffset("NAME",   in: header),
            let tagOff    = columnOffset("TAG",     in: header),
            let digestOff = columnOffset("DIGEST",  in: header)
        else { return [] }

        return lines.dropFirst().compactMap { line in
            let chars = Array(line)
            guard chars.count > nameOff else { return nil }
            let name   = field(chars, from: nameOff,   to: tagOff)
            let tag    = field(chars, from: tagOff,    to: digestOff)
            let digest = field(chars, from: digestOff, to: nil)
            guard !name.isEmpty else { return nil }
            return ImageInfo(name: name, tag: tag, digest: digest)
        }
    }
}
