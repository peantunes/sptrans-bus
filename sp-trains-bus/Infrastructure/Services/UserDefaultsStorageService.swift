import Foundation

class UserDefaultsStorageService: StorageServiceProtocol {
    private let userDefaults: UserDefaults

    private enum Keys {
        static let favoriteStops = "favoriteStops"
        static let homeLocation = "homeLocation"
        static let workLocation = "workLocation"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveFavorite(stop: Stop) {
        var favorites = getFavoriteStops()
        if !favorites.contains(where: { $0.stopId == stop.stopId }) {
            favorites.append(stop)
            saveFavoriteStops(favorites)
        }
    }

    func removeFavorite(stop: Stop) {
        var favorites = getFavoriteStops()
        favorites.removeAll { $0.stopId == stop.stopId }
        saveFavoriteStops(favorites)
    }

    func getFavoriteStops() -> [Stop] {
        if let data = userDefaults.data(forKey: Keys.favoriteStops),
           let stops = try? JSONDecoder().decode([Stop].self, from: data) {
            return stops
        }
        return []
    }

    private func saveFavoriteStops(_ stops: [Stop]) {
        if let encoded = try? JSONEncoder().encode(stops) {
            userDefaults.set(encoded, forKey: Keys.favoriteStops)
        }
    }

    func saveHome(location: Location) {
        if let encoded = try? JSONEncoder().encode(location) {
            userDefaults.set(encoded, forKey: Keys.homeLocation)
        }
    }

    func getHomeLocation() -> Location? {
        if let data = userDefaults.data(forKey: Keys.homeLocation),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            return location
        }
        return nil
    }

    func saveWork(location: Location) {
        if let encoded = try? JSONEncoder().encode(location) {
            userDefaults.set(encoded, forKey: Keys.workLocation)
        }
    }

    func getWorkLocation() -> Location? {
        if let data = userDefaults.data(forKey: Keys.workLocation),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            return location
        }
        return nil
    }
}
