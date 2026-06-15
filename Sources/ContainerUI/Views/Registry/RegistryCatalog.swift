import SwiftUI

let curatedCategories: [RegistryCategory] = [
    RegistryCategory(name: "Databases", icon: "cylinder.split.1x2", entries: [
        RegistryEntry(name: "Memcached",     image: "memcached",    tag: "alpine",    category: "Databases", icon: "bolt.fill",              color: .teal,    defaultPorts: [("11211","11211")],              defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "Redis",         image: "redis",        tag: "7-alpine",  category: "Databases", icon: "bolt.fill",              color: .red,     defaultPorts: [("6379","6379")],                defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "PostgreSQL",    image: "postgres",     tag: "16",        category: "Databases", icon: "externaldrive.fill",     color: .blue,    defaultPorts: [("5432","5432")],                defaultMemory: "512M", defaultEnv: ["POSTGRES_PASSWORD=secret"]),
        RegistryEntry(name: "MySQL",         image: "mysql",        tag: "8",         category: "Databases", icon: "externaldrive.fill",     color: .orange,  defaultPorts: [("3306","3306")],                defaultMemory: "512M", defaultEnv: ["MYSQL_ROOT_PASSWORD=secret"]),
        RegistryEntry(name: "MongoDB",       image: "mongo",        tag: "7",         category: "Databases", icon: "leaf.fill",              color: .green,   defaultPorts: [("27017","27017")],              defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "MariaDB",       image: "mariadb",      tag: "11",        category: "Databases", icon: "externaldrive.fill",     color: .indigo,  defaultPorts: [("3306","3306")],                defaultMemory: "512M", defaultEnv: ["MARIADB_ROOT_PASSWORD=secret"]),
        RegistryEntry(name: "Elasticsearch", image: "elasticsearch",tag: "8.13.0",    category: "Databases", icon: "magnifyingglass.circle.fill", color: .yellow, defaultPorts: [("9200","9200"),("9300","9300")], defaultMemory: "2G", defaultEnv: ["discovery.type=single-node","xpack.security.enabled=false"]),
        RegistryEntry(name: "InfluxDB",      image: "influxdb",     tag: "2",         category: "Databases", icon: "waveform.path.ecg",      color: .purple,  defaultPorts: [("8086","8086")],                defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "Neo4j",         image: "neo4j",        tag: "5",         category: "Databases", icon: "circle.grid.3x3.fill",   color: .blue,    defaultPorts: [("7474","7474"),("7687","7687")], defaultMemory: "1G",  defaultEnv: ["NEO4J_AUTH=none"]),
        RegistryEntry(name: "Cassandra",     image: "cassandra",    tag: "5",         category: "Databases", icon: "server.rack",            color: .teal,    defaultPorts: [("9042","9042")],                defaultMemory: "2G",  defaultEnv: []),
    ]),
    RegistryCategory(name: "Web & Proxy", icon: "network", entries: [
        RegistryEntry(name: "Nginx",         image: "nginx",        tag: "alpine",    category: "Web & Proxy", icon: "network",                    color: .green,  defaultPorts: [("8080","80")],                  defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Apache",        image: "httpd",        tag: "alpine",    category: "Web & Proxy", icon: "globe",                      color: .red,    defaultPorts: [("8080","80")],                  defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Traefik",       image: "traefik",      tag: "v3",        category: "Web & Proxy", icon: "arrow.triangle.swap",         color: .blue,   defaultPorts: [("80","80"),("8080","8080")],    defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "HAProxy",       image: "haproxy",      tag: "alpine",    category: "Web & Proxy", icon: "arrow.triangle.branch",       color: .indigo, defaultPorts: [("8080","8080"),("1936","1936")], defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Caddy",         image: "caddy",        tag: "2",         category: "Web & Proxy", icon: "lock.fill",                   color: .teal,   defaultPorts: [("8080","80"),("8443","443")],   defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Kong",          image: "kong",         tag: "alpine",    category: "Web & Proxy", icon: "point.3.filled.connected.trianglepath.dotted", color: .green, defaultPorts: [("8000","8000"),("8001","8001")], defaultMemory: "512M", defaultEnv: ["KONG_DATABASE=off"]),
    ]),
    RegistryCategory(name: "Monitoring", icon: "chart.xyaxis.line", entries: [
        RegistryEntry(name: "Grafana",       image: "grafana/grafana",  tag: "latest",    category: "Monitoring", icon: "chart.xyaxis.line",        color: .orange, defaultPorts: [("3000","3000")], defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "Loki",          image: "grafana/loki",     tag: "latest",    category: "Monitoring", icon: "doc.text.fill",            color: Color(red: 0.9, green: 0.5, blue: 0.1), defaultPorts: [("3100","3100")], defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "Prometheus",    image: "prom/prometheus",  tag: "latest",    category: "Monitoring", icon: "flame.fill",               color: .red,    defaultPorts: [("9090","9090")], defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "SonarQube",     image: "sonarqube",        tag: "community", category: "Monitoring", icon: "checkmark.shield.fill",    color: .blue,   defaultPorts: [("9000","9000")], defaultMemory: "4G",   defaultEnv: []),
        RegistryEntry(name: "Kibana",        image: "kibana",           tag: "8.13.0",    category: "Monitoring", icon: "chart.bar.fill",           color: .pink,   defaultPorts: [("5601","5601")], defaultMemory: "1G",   defaultEnv: []),
    ]),
    RegistryCategory(name: "Dev Tools", icon: "hammer.fill", entries: [
        RegistryEntry(name: "Jenkins",       image: "jenkins/jenkins",        tag: "lts",    category: "Dev Tools", icon: "gearshape.2.fill",   color: .indigo, defaultPorts: [("8080","8080"),("50000","50000")], defaultMemory: "1G",   defaultEnv: []),
        RegistryEntry(name: "MinIO",         image: "minio/minio",            tag: "latest", category: "Dev Tools", icon: "externaldrive.connected.to.line.below.fill", color: .red, defaultPorts: [("9000","9000"),("9001","9001")], defaultMemory: "512M", defaultEnv: ["MINIO_ROOT_USER=admin","MINIO_ROOT_PASSWORD=secret"]),
        RegistryEntry(name: "Registry",      image: "registry",               tag: "2",      category: "Dev Tools", icon: "shippingbox.fill",   color: .blue,   defaultPorts: [("5000","5000")],  defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Gitea",         image: "gitea/gitea",            tag: "latest", category: "Dev Tools", icon: "arrow.triangle.pull", color: .green, defaultPorts: [("3000","3000"),("22","22")], defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "Adminer",       image: "adminer",                tag: "latest", category: "Dev Tools", icon: "tablecells.fill",    color: .teal,   defaultPorts: [("8080","8080")],  defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Portainer",     image: "portainer/portainer-ce", tag: "latest", category: "Dev Tools", icon: "slider.horizontal.3", color: .blue,  defaultPorts: [("9000","9000"),("9443","9443")], defaultMemory: "256M", defaultEnv: []),
    ]),
    RegistryCategory(name: "Apps", icon: "app.fill", entries: [
        RegistryEntry(name: "WordPress",     image: "wordpress",  tag: "latest",   category: "Apps", icon: "doc.richtext.fill",   color: .blue,      defaultPorts: [("8080","80")],   defaultMemory: "512M", defaultEnv: ["WORDPRESS_DB_PASSWORD=secret"]),
        RegistryEntry(name: "Nextcloud",     image: "nextcloud",  tag: "apache",   category: "Apps", icon: "icloud.fill",         color: .blue,      defaultPorts: [("8080","80")],   defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "Ghost",         image: "ghost",      tag: "alpine",   category: "Apps", icon: "pencil.and.outline",  color: .secondary, defaultPorts: [("2368","2368")], defaultMemory: "512M", defaultEnv: ["NODE_ENV=development"]),
    ]),
    RegistryCategory(name: "Messaging", icon: "message.fill", entries: [
        RegistryEntry(name: "RabbitMQ",      image: "rabbitmq",   tag: "3-management", category: "Messaging", icon: "envelope.fill",           color: .orange, defaultPorts: [("5672","5672"),("15672","15672")], defaultMemory: "512M", defaultEnv: []),
        RegistryEntry(name: "NATS",          image: "nats",       tag: "alpine",        category: "Messaging", icon: "arrow.left.arrow.right",  color: .teal,   defaultPorts: [("4222","4222"),("8222","8222")],   defaultMemory: "128M", defaultEnv: []),
        RegistryEntry(name: "Zookeeper",     image: "zookeeper",  tag: "latest",        category: "Messaging", icon: "circle.grid.cross.fill",  color: .brown,  defaultPorts: [("2181","2181")],   defaultMemory: "512M", defaultEnv: []),
    ]),
    RegistryCategory(name: "Security", icon: "lock.shield.fill", entries: [
        RegistryEntry(name: "Consul",        image: "consul",              tag: "latest", category: "Security", icon: "network.badge.shield.half.filled", color: .pink,   defaultPorts: [("8500","8500"),("8600","8600")], defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "Vault",         image: "hashicorp/vault",     tag: "latest", category: "Security", icon: "lock.shield.fill",  color: .yellow, defaultPorts: [("8200","8200")], defaultMemory: "256M", defaultEnv: []),
        RegistryEntry(name: "Vaultwarden",   image: "vaultwarden/server",  tag: "latest", category: "Security", icon: "key.horizontal.fill", color: .blue,  defaultPorts: [("80","80")],     defaultMemory: "256M", defaultEnv: []),
    ]),
]
