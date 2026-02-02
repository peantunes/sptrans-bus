import Foundation

protocol StorageServiceProtocol {
    func saveFavorite(stop: Stop)
    func removeFavorite(stop: Stop)
    func isFavorite(stopId: Int) -> Bool
    func getFavoriteStops() -> [Stop]
    func saveHome(location: Location)
    func getHomeLocation() -> Location?
    func saveWork(location: Location)
    func getWorkLocation() -> Location?
}
