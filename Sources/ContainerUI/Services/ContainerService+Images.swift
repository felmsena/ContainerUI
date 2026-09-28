import Foundation

extension ContainerService {

    func fetchImages() async {
        update(\.images, (try? await fetchJSONOrText(
            args: [bin] + CLI.imageList(),
            jsonParse: Self.parseImageListJSON,
            textParse: Self.parseImageList
        )) ?? [])
    }

    func deleteImage(_ ref: String) async {
        do { try await cli(CLI.imageDelete(ref)) } catch { report(error, as: String(localized: "Couldn't delete \(ref)")) }
        await fetchImages()
    }

    /// Removes exactly the given images (the ones the UI counted as unused),
    /// rather than `image prune`, whose "dangling only" semantics don't match
    /// what the toolbar shows and whose `--all` would also delete the
    /// system images Apple Container needs.
    func removeImages(_ refs: [String]) async {
        for ref in refs {
            do { try await cli(CLI.imageDelete(ref)) } catch { report(error, as: String(localized: "Couldn't delete \(ref)")) }
        }
        await fetchImages()
    }

    nonisolated static func parseImageList(_ output: String) -> [ImageInfo] {
        tableRows(output, columns: ["NAME", "TAG", "DIGEST"]).map { f in
            ImageInfo(name: f[0], tag: f[1], digest: f[2])
        }
    }

    // MARK: – JSON parsing

    private struct ImageListEntryJSON: Decodable {
        struct Configuration: Decodable { let name: String }
        let id: String
        let configuration: Configuration
    }

    nonisolated static func parseImageListJSON(_ data: Data) -> [ImageInfo]? {
        guard let entries = try? JSONDecoder().decode([ImageListEntryJSON].self, from: data) else { return nil }
        return entries.map { entry in
            let (name, tag) = ImageReference.split(entry.configuration.name)
            return ImageInfo(name: name, tag: tag, digest: entry.id)
        }
    }
}
