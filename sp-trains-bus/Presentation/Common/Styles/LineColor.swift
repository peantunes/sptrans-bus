import Foundation

/// Readable colours for transit lines. Brand colours such as Metrô L4's yellow are
/// too light for white text, or for text and lines on a white card, so they are
/// checked with the WCAG contrast ratio and adjusted when needed.
enum LineColor {
    struct RGB: Equatable {
        var r: Double
        var g: Double
        var b: Double
    }

    /// Text on a badge filled with the line colour (WCAG AA for text).
    static let textContrast = 4.5
    /// Lines, dots and icons drawn in the line colour (WCAG for graphics).
    static let graphicContrast = 3.0

    static let darkText = "1C1C1E"
    static let lightText = "FFFFFF"
    /// Card surfaces: secondarySystemGroupedBackground in light and dark mode.
    static let lightSurface = "FFFFFF"
    static let darkSurface = "1C1C1E"

    static func parse(_ hex: String?) -> RGB? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let int = UInt32(value, radix: 16) else { return nil }
        return RGB(r: Double((int >> 16) & 0xFF) / 255, g: Double((int >> 8) & 0xFF) / 255, b: Double(int & 0xFF) / 255)
    }

    static func hex(_ color: RGB) -> String {
        func channel(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", channel(color.r), channel(color.g), channel(color.b))
    }

    static func luminance(_ color: RGB) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Text colour for a badge filled with `background`. The API's text colour is kept
    /// only when it is readable (it sends white on Metrô L4's yellow).
    static func badgeText(background: String?, preferred: String?) -> String {
        guard let fill = parse(background) else { return lightText }
        if let preferredHex = preferred, let wanted = parse(preferredHex), contrast(fill, wanted) >= textContrast {
            return hex(wanted)
        }
        let dark = parse(darkText)!, light = parse(lightText)!
        return contrast(fill, dark) >= contrast(fill, light) ? darkText : lightText
    }

    /// The line colour, darkened on a light surface (or lightened on a dark one)
    /// until it reaches `minimumContrast` against that surface.
    static func readable(_ lineHex: String?, on surfaceHex: String, minimumContrast: Double) -> String? {
        guard let line = parse(lineHex), let surface = parse(surfaceHex) else { return nil }
        if contrast(line, surface) >= minimumContrast { return hex(line) }
        let target = luminance(surface) > 0.5 ? RGB(r: 0, g: 0, b: 0) : RGB(r: 1, g: 1, b: 1)
        var mixed = line
        for step in 1...20 {
            let t = Double(step) / 20
            mixed = RGB(r: line.r + (target.r - line.r) * t,
                        g: line.g + (target.g - line.g) * t,
                        b: line.b + (target.b - line.b) * t)
            if contrast(mixed, surface) >= minimumContrast { break }
        }
        return hex(mixed)
    }
}
