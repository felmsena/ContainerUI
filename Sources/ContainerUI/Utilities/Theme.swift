import SwiftUI

/// Design-token color palette, matching the values in the design mockup's
/// `THEMES` object. Colors are resolved dynamically at draw time via
/// `NSColor(name:dynamicProvider:)` so a single `Theme.xyz` accessor works
/// for both light and dark automatically, following whatever appearance
/// SwiftUI has resolved for the view (system, or the in-app override
/// applied via `.preferredColorScheme`).
enum Theme {
    static let bg = dynamic(dark: "#0B1220", light: "#F6F7F6")
    static let surface = dynamic(dark: "#121A2C", light: "#FFFFFF")
    static let surface2 = dynamic(dark: "#182238", light: "#EFF1EF")
    static let border = dynamic(dark: Color.white.opacity(0.08), light: Color(hex: "#E3E6E4"))

    static let text = dynamic(dark: "#EDF3F0", light: "#14181A")
    static let text2 = dynamic(dark: "#96A3B0", light: "#5C666B")
    static let text3 = dynamic(dark: "#64707D", light: "#8B9296")

    static let accent = dynamic(dark: "#34D399", light: "#059669")
    static let accentStrong = dynamic(dark: "#10B981", light: "#047857")
    static let accentSoft = dynamic(dark: Color(hex: "#34D399").opacity(0.16), light: Color(hex: "#E5F6EE"))

    static let warn = dynamic(dark: "#F0B254", light: "#B45309")
    static let warnSoft = dynamic(dark: Color(hex: "#F0B254").opacity(0.15), light: Color(hex: "#FCEEDC"))

    static let danger = dynamic(dark: "#F1746E", light: "#C0392E")
    static let dangerSoft = dynamic(dark: Color(hex: "#F1746E").opacity(0.15), light: Color(hex: "#FAE8E6"))

    static let shadow = dynamic(dark: Color.black.opacity(0.4), light: Color(hex: "#141E19").opacity(0.08))

    private static func dynamic(dark: String, light: String) -> Color {
        dynamic(dark: Color(hex: dark), light: Color(hex: light))
    }

    private static func dynamic(dark: Color, light: Color) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        }))
    }
}

extension Color {
    /// Creates a `Color` from a `"#RRGGBB"` or `"#RGB"` hex string. Falls back to clear
    /// on malformed input (should not happen with the hardcoded literals above).
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let r, g, b: Double
        switch s.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

/// In-app appearance override (system / light / dark), persisted via `@AppStorage`
/// and applied at the app root through `.preferredColorScheme`.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
