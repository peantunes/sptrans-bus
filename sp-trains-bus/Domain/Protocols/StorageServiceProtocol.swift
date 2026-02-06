import Foundation

protocol StorageServiceProtocol {
    func saveFavorite(stop: Stop)
    func removeFavorite(stop: Stop)
    func isFavorite(stopId: Int) -> Bool
    func getFavoriteStops() -> [Stop]

    func savePlace(_ place: UserPlace)
    func removePlace(id: UUID)
    func getSavedPlaces() -> [UserPlace]
    func getPlaces(type: UserPlaceType) -> [UserPlace]

    func saveHome(location: Location)
    func getHomeLocation() -> Location?
    func saveWork(location: Location)
    func getWorkLocation() -> Location?
}
