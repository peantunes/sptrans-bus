import SwiftUI

struct AppColors {
    // Primary Colors
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")

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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
}
