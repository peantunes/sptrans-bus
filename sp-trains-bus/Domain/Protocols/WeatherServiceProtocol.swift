import Foundation

protocol WeatherServiceProtocol {
    func fetchDailyWeather(for location: Location) async throws -> WeatherSnapshot
}
