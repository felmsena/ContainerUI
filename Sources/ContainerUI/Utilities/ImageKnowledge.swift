import SwiftUI

/// What the app knows about well-known images: an icon, a color and the
/// ports they usually serve. Matched on whole name *tokens* ("sonar",
/// "scanner", "cli" for `sonar-scanner-cli`) rather than substrings, so
/// "ubuntu" no longer matches "bun", "clickhouse" no longer matches "cli",
/// and "nextcloud" no longer matches "next".
struct ImageHint {
    let names: Set<String>
    let symbol: String
    let color: Color
    var ports: [(port: Int, label: String)] = []
}

enum ImageKnowledge {
    private static let code = "chevron.left.forwardslash.chevron.right"
    private static let db = "cylinder.split.1x2.fill"

    /// Checked in order; the first hint sharing a token with the image wins.
    static let hints: [ImageHint] = [
        ImageHint(names: ["postgres", "postgresql", "pgvector", "postgis"], symbol: db, color: .blue, ports: [(5432, "PostgreSQL")]),
        ImageHint(names: ["mysql", "mariadb"], symbol: db, color: .orange, ports: [(3306, "MySQL")]),
        ImageHint(names: ["mongo", "mongodb"], symbol: db, color: .green, ports: [(27017, "MongoDB")]),
        ImageHint(names: ["redis", "valkey", "keydb"], symbol: "bolt.fill", color: .red, ports: [(6379, "Redis")]),
        ImageHint(names: ["memcached"], symbol: "bolt.fill", color: .teal, ports: [(11211, "Memcached")]),
        ImageHint(names: ["nginx", "caddy", "httpd", "apache", "haproxy"], symbol: "network", color: .blue, ports: [(80, "HTTP"), (443, "HTTPS")]),
        ImageHint(names: ["traefik"], symbol: "network", color: .blue, ports: [(80, "HTTP"), (8080, "Dashboard")]),
        ImageHint(names: ["node", "deno", "bun"], symbol: code, color: Color(red: 0.3, green: 0.7, blue: 0.3), ports: [(3000, "HTTP")]),
        ImageHint(names: ["python", "pypy"], symbol: code, color: .yellow),
        ImageHint(names: ["ruby", "rails"], symbol: code, color: .red),
        ImageHint(names: ["golang", "go"], symbol: code, color: .cyan),
        ImageHint(names: ["rust"], symbol: code, color: .orange),
        ImageHint(names: ["openjdk", "java", "gradle", "maven", "eclipse-temurin", "temurin"], symbol: code, color: .red),
        ImageHint(names: ["ubuntu", "debian", "centos", "fedora", "rockylinux", "almalinux", "archlinux"], symbol: "terminal.fill", color: .purple),
        ImageHint(names: ["alpine", "busybox"], symbol: "mountain.2.fill", color: .gray),
        ImageHint(names: ["kafka"], symbol: "arrow.left.arrow.right.circle.fill", color: .orange, ports: [(9092, "Broker")]),
        ImageHint(names: ["rabbitmq"], symbol: "arrow.left.arrow.right.circle.fill", color: .orange, ports: [(5672, "AMQP"), (15672, "Management")]),
        ImageHint(names: ["nats"], symbol: "arrow.left.arrow.right.circle.fill", color: .teal, ports: [(4222, "Client"), (8222, "Monitoring")]),
        ImageHint(names: ["elasticsearch", "opensearch"], symbol: "magnifyingglass.circle.fill", color: Color(red: 1.0, green: 0.6, blue: 0.1), ports: [(9200, "HTTP"), (9300, "Transport")]),
        ImageHint(names: ["kibana"], symbol: "magnifyingglass.circle.fill", color: .pink, ports: [(5601, "Kibana")]),
        ImageHint(names: ["grafana"], symbol: "chart.xyaxis.line", color: .orange, ports: [(3000, "Grafana")]),
        ImageHint(names: ["prometheus"], symbol: "chart.xyaxis.line", color: .orange, ports: [(9090, "HTTP")]),
        ImageHint(names: ["jenkins"], symbol: "gearshape.2.fill", color: .indigo, ports: [(8080, "HTTP"), (50000, "Agent")]),
        ImageHint(names: ["gitlab"], symbol: "gearshape.2.fill", color: .indigo, ports: [(80, "HTTP"), (443, "HTTPS"), (22, "SSH")]),
        ImageHint(names: ["gitea"], symbol: "arrow.triangle.pull", color: .green, ports: [(3000, "HTTP")]),
        ImageHint(names: ["wordpress", "ghost", "drupal", "nextcloud"], symbol: "globe", color: .blue, ports: [(80, "HTTP")]),
        ImageHint(names: ["minio"], symbol: "externaldrive.fill", color: .yellow, ports: [(9000, "API"), (9001, "Console")]),
        ImageHint(names: ["sonarqube"], symbol: "doc.text.magnifyingglass", color: Color(red: 0.2, green: 0.55, blue: 0.85), ports: [(9000, "SonarQube")]),
        ImageHint(names: ["sonar", "scanner", "cli"], symbol: "terminal.fill", color: .indigo),
    ]

    /// Lowercased tokens of the image's repository name, without registry,
    /// namespace, tag or digest: "docker.io/library/sonar-scanner-cli:5" →
    /// ["sonar-scanner-cli", "sonar", "scanner", "cli"] (whole name first).
    static func tokens(_ image: String) -> [String] {
        var base = image.split(separator: "/").last.map(String.init) ?? image
        if let at = base.firstIndex(of: "@") { base = String(base[..<at]) }
        if let colon = base.firstIndex(of: ":") { base = String(base[..<colon]) }
        base = base.lowercased()
        let parts = base.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        return [base] + parts
    }

    static func hint(for image: String) -> ImageHint? {
        let toks = tokens(image)
        return hints.first { hint in toks.contains(where: hint.names.contains) }
    }
}

func imageIcon(for name: String) -> (symbol: String, color: Color) {
    guard let hint = ImageKnowledge.hint(for: name) else { return ("shippingbox.fill", .secondary) }
    return (hint.symbol, hint.color)
}
