import Foundation
import CoreLocation
import WeatherKit

final class WeatherKitCachedService: WeatherServiceProtocol {
    private let fileManager: FileManager
    private let calendar: Calendar
    private let cacheFileName = "weather_daily_cache_v1.json"

    init(
        fileManager: FileManager = .default,
        calendar: Calendar = .current
    ) {
        self.fileManager = fileManager
        self.calendar = calendar
    }

    func fetchDailyWeather(for location: Location) async throws -> WeatherSnapshot {
        let cached = loadCache()

        if let cached, calendar.isDate(cached.savedAt, inSameDayAs: Date()) {
            return cached
        }

        do {
            let fresh = try await fetchFromWeatherKit(for: location)
            saveCache(fresh)
            return fresh
        } catch {
            // If WeatherKit auth/network fails, preserve UX by serving stale cache.
            if let cached {
                return cached
            }
            throw error
        }
    }

    private func fetchFromWeatherKit(for location: Location) async throws -> WeatherSnapshot {
        let coordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let weather = try await WeatherService.shared.weather(for: coordinate)

        let hourlyForecast = Array(weather.hourlyForecast.forecast.prefix(24))
        let dailyForecast = Array(weather.dailyForecast.forecast.prefix(10))
        let precipitationChance = hourlyForecast.first.map { percentValue($0.precipitationChance) } ?? 0

        let current = WeatherCurrentSnapshot(
            date: weather.currentWeather.date,
            symbolName: weather.currentWeather.symbolName,
            conditionDescription: conditionText(weather.currentWeather.condition),
            temperatureCelsius: celsius(weather.currentWeather.temperature),
            apparentTemperatureCelsius: celsius(weather.currentWeather.apparentTemperature),
            humidityPercent: percentValue(weather.currentWeather.humidity),
            precipitationChancePercent: precipitationChance,
            windSpeedKilometersPerHour: kilometersPerHour(weather.currentWeather.wind.speed),
            pressureHPa: hectoPascal(weather.currentWeather.pressure),
            visibilityKilometers: kilometers(weather.currentWeather.visibility),
            cloudCoverPercent: percentValue(weather.currentWeather.cloudCover),
            uvIndex: Double(weather.currentWeather.uvIndex.value),
            dewPointCelsius: celsius(weather.currentWeather.dewPoint)
        )

        let hourly = hourlyForecast.map { hour in
            WeatherHourlySnapshot(
                date: hour.date,
                symbolName: hour.symbolName,
                conditionDescription: conditionText(hour.condition),
                temperatureCelsius: celsius(hour.temperature),
                precipitationChancePercent: percentValue(hour.precipitationChance),
                precipitationAmountMillimeters: millimeters(hour.precipitationAmount),
                humidityPercent: percentValue(hour.humidity),
                cloudCoverPercent: percentValue(hour.cloudCover),
                windSpeedKilometersPerHour: kilometersPerHour(hour.wind.speed),
                uvIndex: Double(hour.uvIndex.value)
            )
        }

        let daily = dailyForecast.map { day in
            WeatherDailySnapshot(
                date: day.date,
                symbolName: day.symbolName,
                conditionDescription: conditionText(day.condition),
                lowTemperatureCelsius: celsius(day.lowTemperature),
                highTemperatureCelsius: celsius(day.highTemperature),
                precipitationChancePercent: percentValue(day.precipitationChance),
                precipitationAmountMillimeters: millimeters(day.precipitationAmountByType.precipitation),
                snowfallAmountCentimeters: centimeters(day.precipitationAmountByType.snowfallAmount.amount),
                sunrise: day.sun.sunrise,
                sunset: day.sun.sunset
            )
        }

        return WeatherSnapshot(
            savedAt: Date(),
            location: location,
            current: current,
            hourly: hourly,
            daily: daily
        )
    }

    private func loadCache() -> WeatherSnapshot? {
        guard let cacheURL = cacheFileURL(),
              let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeatherSnapshot.self, from: data)
    }

    private func saveCache(_ snapshot: WeatherSnapshot) {
        guard let cacheURL = cacheFileURL() else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            print("Weather cache write failed: \(error.localizedDescription)")
        }
    }

    private func cacheFileURL() -> URL? {
        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let weatherDirectory = appSupportDirectory.appendingPathComponent("WeatherCache", isDirectory: true)
        do {
            try fileManager.createDirectory(at: weatherDirectory, withIntermediateDirectories: true)
            return weatherDirectory.appendingPathComponent(cacheFileName)
        } catch {
            print("Weather cache directory creation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func celsius(_ value: Measurement<UnitTemperature>) -> Double {
        value.converted(to: .celsius).value
    }

    private func kilometersPerHour(_ value: Measurement<UnitSpeed>) -> Double {
        value.converted(to: .kilometersPerHour).value
    }

    private func kilometers(_ value: Measurement<UnitLength>) -> Double {
        value.converted(to: .kilometers).value
    }

    private func hectoPascal(_ value: Measurement<UnitPressure>) -> Double {
        value.converted(to: .hectopascals).value
    }

    private func millimeters(_ value: Measurement<UnitLength>) -> Double {
        value.converted(to: .millimeters).value
    }

    private func centimeters(_ value: Measurement<UnitLength>) -> Double {
        value.converted(to: .centimeters).value
    }

    private func percentValue(_ value: Double) -> Double {
        max(0, min(100, value * 100))
    }

    private func conditionText(_ condition: WeatherCondition) -> String {
        String(describing: condition)
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
