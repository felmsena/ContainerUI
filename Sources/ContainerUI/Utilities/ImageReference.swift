import Foundation

/// Parses OCI image references as returned by `container`'s JSON output,
/// e.g. "docker.io/library/postgres:16" or "ghcr.io/apple/vminit:0.33.3".
enum ImageReference {
    /// Splits a reference into (name, tag), stripping the implicit
    /// "docker.io/" registry and "library/" namespace the CLI itself omits
    /// from its table output (so JSON- and text-parsed names line up).
    static func split(_ ref: String) -> (name: String, tag: String) {
        var name = ref
        var tag = "latest"

        if let lastSlash = ref.lastIndex(of: "/") {
            let afterSlash = ref.index(after: lastSlash)
            if let colon = ref[afterSlash...].lastIndex(of: ":") {
                name = String(ref[..<colon])
                tag = String(ref[ref.index(after: colon)...])
            }
        } else if let colon = ref.lastIndex(of: ":") {
            name = String(ref[..<colon])
            tag = String(ref[ref.index(after: colon)...])
        }

        if name.hasPrefix("docker.io/") {
            name.removeFirst("docker.io/".count)
            if name.hasPrefix("library/") {
                name.removeFirst("library/".count)
            }
        }

        return (name, tag.isEmpty ? "latest" : tag)
    }
}

/// Exact match between a container's image reference and a known image,
/// after normalizing registry/tag — unlike `hasPrefix`, "postgres" never
/// matches "postgres-custom".
func imageMatches(containerImage: String, image: ImageInfo) -> Bool {
    let (name, tag) = ImageReference.split(containerImage)
    return name == image.name && tag == image.tag
}
