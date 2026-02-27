import Foundation

enum FeatureToggles {
    // Release-ready feature set.
    static let isSearchEnabled = false
    static let isWeatherEnabled = false
    static let isHomeWorkLocationsEnabled = false
    static let isOlhoVivoArrivalsEnabled = true

    static func olhoVivoAPIKey(bundle: Bundle = .main) -> String? {
        guard isOlhoVivoArrivalsEnabled else { return nil }
        guard let rawValue = bundle.object(forInfoDictionaryKey: "OLHO_VIVO_API_KEY") as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var availableUserPlaceTypes: [UserPlaceType] {
        if isHomeWorkLocationsEnabled {
            return UserPlaceType.allCases
        }
        return [.study, .custom]
    }

    static func isUserPlaceTypeEnabled(_ type: UserPlaceType) -> Bool {
        availableUserPlaceTypes.contains(type)
    }
}
