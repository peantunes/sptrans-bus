import Foundation

enum FeatureToggles {
    // Release-ready feature set.
    static let isSearchEnabled = false
    static let isWeatherEnabled = false
    static let isHomeWorkLocationsEnabled = false

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
