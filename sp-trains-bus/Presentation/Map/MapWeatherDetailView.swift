import SwiftUI
import Charts
import UIKit

struct MapWeatherDetailView: View {
    let snapshot: WeatherSnapshot

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentSummaryCard
                    metricsGrid
                    hourlyTemperatureChart
                    hourlyPrecipitationChart
                    weeklyTemperatureChart
                    weeklyForecastList
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var currentSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Image(systemName: resolvedSymbolName(snapshot.current.symbolName))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(AppColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.current.conditionDescription)
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)

                        Text(snapshot.savedAt, style: .date)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }

                    Spacer()

                    Text("\(Int(snapshot.current.temperatureCelsius.rounded()))°")
                        .font(AppFonts.largeTitle())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.text)
                }

                if let today = snapshot.daily.first {
                    Text("H \(Int(today.highTemperatureCelsius.rounded()))° • L \(Int(today.lowTemperatureCelsius.rounded()))°")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.75))
                }
            }
        }
    }

    private var metricsGrid: some View {
        let items: [(String, String, String)] = [
            ("Feels Like", "\(Int(snapshot.current.apparentTemperatureCelsius.rounded()))°", "thermometer"),
            ("Humidity", "\(Int(snapshot.current.humidityPercent.rounded()))%", "humidity.fill"),
            ("Wind", "\(Int(snapshot.current.windSpeedKilometersPerHour.rounded())) km/h", "wind"),
            ("UV", "\(Int(snapshot.current.uvIndex.rounded()))", "sun.max.fill"),
            ("Visibility", "\(Int(snapshot.current.visibilityKilometers.rounded())) km", "eye.fill"),
            ("Pressure", "\(Int(snapshot.current.pressureHPa.rounded())) hPa", "gauge")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items, id: \.0) { item in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(item.0, systemImage: item.2)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.7))
                        Text(item.1)
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var hourlyTemperatureChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today Temperature")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(snapshot.hourly.prefix(24)) { hour in
                    LineMark(
                        x: .value("Hour", hour.date),
                        y: .value("Temperature (°C)", hour.temperatureCelsius)
                    )
                    .foregroundStyle(AppColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Hour", hour.date),
                        y: .value("Temperature (°C)", hour.temperatureCelsius)
                    )
                    .foregroundStyle(AppColors.accent.opacity(0.18))
                }
                .frame(height: 180)
            }
        }
    }

    private var hourlyPrecipitationChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today Rain Chance")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(snapshot.hourly.prefix(24)) { hour in
                    BarMark(
                        x: .value("Hour", hour.date),
                        y: .value("Chance (%)", hour.precipitationChancePercent)
                    )
                    .foregroundStyle(AppColors.statusWarning)
                }
                .frame(height: 160)
            }
        }
    }

    private var weeklyTemperatureChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Week Trend")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(snapshot.daily.prefix(7)) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("High", day.highTemperatureCelsius)
                    )
                    .foregroundStyle(AppColors.statusWarning)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Low", day.lowTemperatureCelsius)
                    )
                    .foregroundStyle(AppColors.primary)
                    .symbol(.square)
                }
                .frame(height: 180)
            }
        }
    }

    private var weeklyForecastList: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Week Forecast")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                ForEach(Array(snapshot.daily.prefix(7))) { day in
                    HStack(spacing: 10) {
                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)
                            .frame(width: 36, alignment: .leading)

                        Image(systemName: resolvedSymbolName(day.symbolName))
                            .foregroundColor(AppColors.accent)

                        Text("\(Int(day.lowTemperatureCelsius.rounded()))°/\(Int(day.highTemperatureCelsius.rounded()))°")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Spacer()

                        Text("\(Int(day.precipitationChancePercent.rounded()))%")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.7))
                    }
                }
            }
        }
    }

    private func resolvedSymbolName(_ symbolName: String) -> String {
        if UIImage(systemName: symbolName) != nil {
            return symbolName
        }
        return "cloud.sun.fill"
    }
}
