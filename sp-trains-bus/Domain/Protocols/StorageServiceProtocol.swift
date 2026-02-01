import Foundation

protocol StorageServiceProtocol {
    func saveFavorite(stop: Stop)
    func removeFavorite(stop: Stop)
    func isFavorite(stopId: String) -> Bool
    func getFavoriteStops() -> [Stop]
    func saveHome(location: Location)
    func getHomeLocation() -> Location?
    func saveWork(location: Location)
    func getWorkLocation() -> Location?
}
