import Foundation

/// One service inside a `ComposeGroup`, as declared under `services:` in a
/// compose-lite YAML document. Fields keep their raw string form (e.g.
/// `"5432:5432"` for a port) — parsing those into structured types happens
/// at the call site that actually needs it (`container run` argument
/// building), so this model stays a faithful mirror of the YAML.
struct ComposeService: Equatable {
    let name: String
    var image: String
    var ports: [String] = []
    var env: [String] = []
    var volumes: [String] = []
    var dependsOn: [String] = []
}

/// A parsed compose-lite document: an ordered list of services (parse
/// order, not dependency order — see `ComposeParser.topologicalOrder`).
struct ComposeGroup: Equatable {
    var services: [ComposeService]
}

enum ComposeParseError: Error, Equatable, CustomStringConvertible {
    case emptyDocument
    case missingServicesKey
    case badIndentation(line: Int)
    case invalidServiceHeader(line: Int)
    case unknownKey(String, service: String, line: Int)
    case missingImage(service: String)
    case duplicateService(String, line: Int)
    case malformedListItem(String, key: String, service: String, line: Int)
    case unknownDependency(String, service: String)
    case dependencyCycle([String])

    var description: String {
        switch self {
        case .emptyDocument:
            return "The document is empty."
        case .missingServicesKey:
            return "Expected a top-level \"services:\" key."
        case .badIndentation(let line):
            return "Line \(line): inconsistent indentation."
        case .invalidServiceHeader(let line):
            return "Line \(line): expected a service name ending in \":\"."
        case .unknownKey(let key, let service, let line):
            return "Line \(line): unknown key \"\(key)\" in service \"\(service)\". Allowed: image, ports, env, volumes, depends_on."
        case .missingImage(let service):
            return "Service \"\(service)\" is missing a required \"image\" key."
        case .duplicateService(let name, let line):
            return "Line \(line): service \"\(name)\" is declared more than once."
        case .malformedListItem(let item, let key, let service, let line):
            return "Line \(line): malformed \"\(key)\" entry \"\(item)\" in service \"\(service)\"."
        case .unknownDependency(let dep, let service):
            return "Service \"\(service)\" depends on unknown service \"\(dep)\"."
        case .dependencyCycle(let cycle):
            return "Dependency cycle: \(cycle.joined(separator: " → "))."
        }
    }
}

/// Hand-rolled parser for a deliberately small YAML subset — just enough to
/// express compose-lite groups without pulling in a YAML dependency. It
/// supports exactly:
///
/// ```yaml
/// services:
///   <name>:
///     image: <ref>
///     ports:
///       - "<host>:<container>"
///     env:
///       - KEY=VALUE
///     volumes:
///       - <source>:<target>
///     depends_on:
///       - <other service name>
/// ```
///
/// No anchors, no multiline scalars, no nested maps beyond this shape.
/// Indentation must be exactly 2 spaces per level (services at 2, keys at
/// 4, list items at 6) — anything else is a parse error rather than a
/// best-effort guess, so mistakes surface immediately in the editor.
enum ComposeParser {
    private static let serviceIndent = 2
    private static let keyIndent = 4
    private static let listItemIndent = 6
    private static let allowedKeys: Set<String> = ["image", "ports", "env", "volumes", "depends_on"]
    private static let listKeys: Set<String> = ["ports", "env", "volumes", "depends_on"]

    nonisolated static func parse(_ yaml: String) -> Result<ComposeGroup, ComposeParseError> {
        let rawLines = yaml.components(separatedBy: .newlines)
        // (1-based line number, indent, content) for every non-blank, non-comment line.
        let lines: [(Int, Int, String)] = rawLines.enumerated().compactMap { idx, raw in
            let stripped = stripComment(raw)
            guard !stripped.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let indent = stripped.prefix { $0 == " " }.count
            let content = stripped.trimmingCharacters(in: .whitespaces)
            return (idx + 1, indent, content)
        }

        guard !lines.isEmpty else { return .failure(.emptyDocument) }
        guard lines[0].1 == 0, lines[0].2 == "services:" else { return .failure(.missingServicesKey) }

        var services: [ComposeService] = []
        var seenNames: Set<String> = []
        var i = 1

        while i < lines.count {
            let (lineNo, indent, content) = lines[i]
            guard indent == serviceIndent else { return .failure(.badIndentation(line: lineNo)) }
            guard content.hasSuffix(":"), content.count > 1 else { return .failure(.invalidServiceHeader(line: lineNo)) }
            let name = String(content.dropLast())
            guard !name.isEmpty, !name.contains(" ") else { return .failure(.invalidServiceHeader(line: lineNo)) }
            guard !seenNames.contains(name) else { return .failure(.duplicateService(name, line: lineNo)) }
            seenNames.insert(name)
            i += 1

            var image: String?
            var ports: [String] = []
            var env: [String] = []
            var volumes: [String] = []
            var dependsOn: [String] = []

            while i < lines.count, lines[i].1 >= keyIndent {
                let (keyLine, keyIndentLevel, keyContent) = lines[i]
                guard keyIndentLevel == keyIndent else { return .failure(.badIndentation(line: keyLine)) }

                guard let colon = keyContent.firstIndex(of: ":") else { return .failure(.badIndentation(line: keyLine)) }
                let key = String(keyContent[keyContent.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let inlineValue = String(keyContent[keyContent.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                guard allowedKeys.contains(key) else { return .failure(.unknownKey(key, service: name, line: keyLine)) }
                i += 1

                if key == "image" {
                    guard !inlineValue.isEmpty else { return .failure(.missingImage(service: name)) }
                    image = unquote(inlineValue)
                    continue
                }

                // List-valued key: consume following "- item" lines at listItemIndent.
                guard inlineValue.isEmpty else {
                    return .failure(.malformedListItem(inlineValue, key: key, service: name, line: keyLine))
                }
                var items: [String] = []
                while i < lines.count, lines[i].1 >= listItemIndent {
                    let (itemLine, itemIndentLevel, itemContent) = lines[i]
                    guard itemIndentLevel == listItemIndent else { return .failure(.badIndentation(line: itemLine)) }
                    guard itemContent.hasPrefix("- ") || itemContent == "-" else {
                        return .failure(.malformedListItem(itemContent, key: key, service: name, line: itemLine))
                    }
                    let value = unquote(String(itemContent.dropFirst(itemContent.hasPrefix("- ") ? 2 : 1)).trimmingCharacters(in: .whitespaces))
                    guard !value.isEmpty else {
                        return .failure(.malformedListItem(itemContent, key: key, service: name, line: itemLine))
                    }
                    items.append(value)
                    i += 1
                }
                switch key {
                case "ports": ports = items
                case "env": env = items
                case "volumes": volumes = items
                case "depends_on": dependsOn = items
                default: break
                }
            }

            guard let resolvedImage = image else { return .failure(.missingImage(service: name)) }
            services.append(ComposeService(
                name: name, image: resolvedImage, ports: ports, env: env,
                volumes: volumes, dependsOn: dependsOn
            ))
        }

        for service in services {
            for dep in service.dependsOn where !seenNames.contains(dep) {
                return .failure(.unknownDependency(dep, service: service.name))
            }
        }

        return .success(ComposeGroup(services: services))
    }

    /// Kahn's algorithm: services with no unresolved `depends_on` come
    /// first, in declaration order among ties. Any leftover services once
    /// no more can be resolved indicate a cycle.
    nonisolated static func topologicalOrder(_ group: ComposeGroup) -> Result<[ComposeService], ComposeParseError> {
        var remaining = group.services
        var resolved: Set<String> = []
        var ordered: [ComposeService] = []

        while !remaining.isEmpty {
            let ready = remaining.filter { service in service.dependsOn.allSatisfy(resolved.contains) }
            guard !ready.isEmpty else {
                return .failure(.dependencyCycle(remaining.map(\.name)))
            }
            for service in ready {
                ordered.append(service)
                resolved.insert(service.name)
            }
            let readyNames = Set(ready.map(\.name))
            remaining.removeAll { readyNames.contains($0.name) }
        }
        return .success(ordered)
    }

    private static func stripComment(_ line: String) -> String {
        guard line.contains("#") else { return line }
        // A '#' inside quotes isn't a comment; only strip unquoted ones.
        var inQuotes = false
        var quoteChar: Character = "\""
        for index in line.indices {
            let ch = line[index]
            if inQuotes {
                if ch == quoteChar { inQuotes = false }
            } else if ch == "\"" || ch == "'" {
                inQuotes = true
                quoteChar = ch
            } else if ch == "#" {
                return String(line[line.startIndex..<index])
            }
        }
        return line
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
