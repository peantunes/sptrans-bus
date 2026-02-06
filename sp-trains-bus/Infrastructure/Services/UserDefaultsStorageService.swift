import Foundation

class UserDefaultsStorageService: StorageServiceProtocol {
    private let userDefaults: UserDefaults

    private enum Keys {
        static let favoriteStops = "favoriteStops"
        static let savedPlaces = "savedPlaces"
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

    func isFavorite(stopId: Int) -> Bool {
        return getFavoriteStops().contains { $0.stopId == stopId }
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

    func savePlace(_ place: UserPlace) {
        var places = getSavedPlaces()
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = place
        } else {
            places.append(place)
        }
        savePlaces(places)
    }

    func removePlace(id: UUID) {
        var places = getSavedPlaces()
        places.removeAll { $0.id == id }
        savePlaces(places)
    }

    func getSavedPlaces() -> [UserPlace] {
        if let data = userDefaults.data(forKey: Keys.savedPlaces),
           let places = try? JSONDecoder().decode([UserPlace].self, from: data) {
            return places
        }
        return []
    }

    func getPlaces(type: UserPlaceType) -> [UserPlace] {
        return getSavedPlaces().filter { $0.type == type }
    }

    private func savePlaces(_ places: [UserPlace]) {
        if let encoded = try? JSONEncoder().encode(places) {
            userDefaults.set(encoded, forKey: Keys.savedPlaces)
        }
    }

    func saveHome(location: Location) {
        let homePlace = UserPlace(name: "Home", location: location, type: .home)
        var places = getSavedPlaces()
        places.removeAll { $0.type == .home }
        places.append(homePlace)
        savePlaces(places)

        if let encoded = try? JSONEncoder().encode(location) {
            userDefaults.set(encoded, forKey: Keys.homeLocation)
        }
    }

    func getHomeLocation() -> Location? {
        if let homePlace = getPlaces(type: .home).first {
            return homePlace.location
        }

        if let data = userDefaults.data(forKey: Keys.homeLocation),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            return location
        }
        return nil
    }

    func saveWork(location: Location) {
        let workPlace = UserPlace(name: "Work", location: location, type: .work)
        var places = getSavedPlaces()
        places.removeAll { $0.type == .work }
        places.append(workPlace)
        savePlaces(places)

        if let encoded = try? JSONEncoder().encode(location) {
            userDefaults.set(encoded, forKey: Keys.workLocation)
        }
    }

    func getWorkLocation() -> Location? {
        if let workPlace = getPlaces(type: .work).first {
            return workPlace.location
        }

        if let data = userDefaults.data(forKey: Keys.workLocation),
           let location = try? JSONDecoder().decode(Location.self, from: data) {
            return location
        }
        return nil
    }
}
