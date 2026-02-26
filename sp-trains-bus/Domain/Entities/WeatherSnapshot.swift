import Foundation

struct WeatherSnapshot: Codable {
    let savedAt: Date
    let location: Location
    let current: WeatherCurrentSnapshot
    let hourly: [WeatherHourlySnapshot]
    let daily: [WeatherDailySnapshot]
}

struct WeatherCurrentSnapshot: Codable {
    let date: Date
    let symbolName: String
    let conditionDescription: String
    let temperatureCelsius: Double
    let apparentTemperatureCelsius: Double
    let humidityPercent: Double
    let precipitationChancePercent: Double
    let windSpeedKilometersPerHour: Double
    let pressureHPa: Double
    let visibilityKilometers: Double
    let cloudCoverPercent: Double
    let uvIndex: Double
    let dewPointCelsius: Double
}

struct WeatherHourlySnapshot: Codable, Identifiable {
    var id: Date { date }

    let date: Date
    let symbolName: String
    let conditionDescription: String
    let temperatureCelsius: Double
    let precipitationChancePercent: Double
    let precipitationAmountMillimeters: Double
    let humidityPercent: Double
    let cloudCoverPercent: Double
    let windSpeedKilometersPerHour: Double
    let uvIndex: Double
}

struct WeatherDailySnapshot: Codable, Identifiable {
    var id: Date { date }

    let date: Date
    let symbolName: String
    let conditionDescription: String
    let lowTemperatureCelsius: Double
    let highTemperatureCelsius: Double
    let precipitationChancePercent: Double
    let precipitationAmountMillimeters: Double
    let snowfallAmountCentimeters: Double
    let sunrise: Date?
    let sunset: Date?
}
