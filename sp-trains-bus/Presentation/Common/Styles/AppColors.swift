import SwiftUI
import UIKit

struct AppColors {
    // Primary Colors
    static var primary: Color { AppTheme.primaryColor }
    static let secondary = Color("SecondaryColor")
    static var accent: Color { AppTheme.accentColor }

    // Neutral Colors
    static let background = Color("BackgroundColor")
    static let text = Color("TextColor")
    static let lightGray = Color("LightGray")
    static let darkGray = Color("DarkGray")

    // Metro Line Colors (from Tasks.md)
    static let metroL1Azul = Color(hex: "0455A1")
    static let metroL2Verde = Color(hex: "007E5E")
    static let metroL3Vermelha = Color(hex: "EE372F")
    static let metroL4Amarela = Color(hex: "FFD700")
    static let metroL5Lilas = Color(hex: "9B3894")
    static let metroL7Rubi = Color(hex: "CA016B")
    static let metroL8Diamante = Color(hex: "97A098")
    static let metroL9Esmeralda = Color(hex: "01A9A7")
    static let metroL10Turquesa = Color(hex: "008B8B")
    static let metroL11Coral = Color(hex: "F04E23")
    static let metroL12Safira = Color(hex: "083D8B")
    static let metroL13Jade = Color(hex: "00B352")

    // Status Colors
    static let statusNormal = Color("StatusNormal")
    static let statusWarning = Color("StatusWarning")
    static let statusAlert = Color("StatusAlert")
}

struct AppTheme {
    struct AccentColorOption: Identifiable {
        let id: String
        let name: String
        let hex: String
        let color: Color

        init(name: String, hex: String) {
            self.id = hex
            self.name = name
            self.hex = hex
            self.color = Color(hex: hex)
        }
    }

    static let selectedPrimaryColorHexKey = "selected_primary_color_hex"
    static let defaultPrimaryColorHex = "007AFF"

    static let accentColorOptions: [AccentColorOption] = [
        AccentColorOption(name: "Blue", hex: "007AFF"),
        AccentColorOption(name: "Green", hex: "34C759"),
        AccentColorOption(name: "Teal", hex: "00AFAF"),
        AccentColorOption(name: "Orange", hex: "FF9500"),
        AccentColorOption(name: "Red", hex: "FF3B30"),
        AccentColorOption(name: "Pink", hex: "FF2D55"),
        AccentColorOption(name: "Indigo", hex: "5856D6"),
        AccentColorOption(name: "Gray", hex: "5E5E5E")
    ]

    static var primaryColor: Color {
        color(forStoredHex: UserDefaults.standard.string(forKey: selectedPrimaryColorHexKey) ?? defaultPrimaryColorHex)
    }

    static var accentColor: Color {
        color(forStoredHex: UserDefaults.standard.string(forKey: selectedPrimaryColorHexKey) ?? defaultPrimaryColorHex)
    }

    static func color(forStoredHex hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Color("PrimaryColor")
        }
        return Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !hex.isEmpty else {
            self = AppColors.background
            return
        }
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [1, 1, 1, 1]
        let r = Int((components.count > 0 ? components[0] : 1) * 255)
        let g = Int((components.count > 1 ? components[1] : 1) * 255)
        let b = Int((components.count > 2 ? components[2] : 1) * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
