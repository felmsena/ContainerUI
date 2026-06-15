import Foundation

struct PortMapping: Identifiable {
    let id = UUID()
    var host: String
    var container: String
}

struct VolumeMount: Identifiable {
    let id = UUID()
    var source: String
    var target: String
}

struct EnvVar: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}
