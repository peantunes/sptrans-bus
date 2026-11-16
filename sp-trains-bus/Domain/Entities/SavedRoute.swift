import Foundation

/// Free tier limits for the planner; Premium has none (same rules as Android).
enum PlannerLimits {
    static let freeSavedRoutes = 2
    static let freeDailySearches = 5
}

/// A named place with coordinates, as stored for the planner.
struct PlannerPlace: Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double

    init(name: String, location: Location) {
        self.name = name
        self.latitude = location.latitude
        self.longitude = location.longitude
    }

    var location: Location { Location(latitude: latitude, longitude: longitude) }
}

/// A saved origin → destination pair. "Current location" origins are resolved when used.
struct SavedRoute: Codable, Equatable, Identifiable {
    let id: String
    let origin: PlannerPlace
    let destination: PlannerPlace
    let originIsCurrentLocation: Bool
}

/// Last planner form, restored when the screen opens again. Times are not kept: searches start from now.
struct PlanFormSnapshot: Codable, Equatable {
    var origin: PlannerPlace?
    var originIsCurrentLocation: Bool
    var destination: PlannerPlace?
    var rankingPriority: String
    var maxTransfers: Int
}

/// Why the free tier stopped an action; the screen offers Premium.
enum PlannerPremiumPrompt: String, Identifiable {
    case saveLimit
    case searchLimit
    case chooseTime

    var id: String { rawValue }
}
