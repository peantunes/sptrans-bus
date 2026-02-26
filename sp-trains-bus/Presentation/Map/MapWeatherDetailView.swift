import SwiftUI
import Charts
import UIKit

struct MapWeatherDetailView: View {
    let snapshot: WeatherSnapshot
    @State private var selectedDayIndex = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentSummaryCard
                    hourlyTemperatureChart
                    hourlyPrecipitationChart
                    weeklyForecastCarousel
                    selectedDayDetailCard
                    metricsGrid
                    weeklyTemperatureChart
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(localized("map.weather.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var displayedDailyForecast: [WeatherDailySnapshot] {
        Array(snapshot.daily.prefix(7))
    }

    private var selectedDay: WeatherDailySnapshot? {
        guard !displayedDailyForecast.isEmpty else { return nil }
        let clampedIndex = min(max(selectedDayIndex, 0), displayedDailyForecast.count - 1)
        return displayedDailyForecast[clampedIndex]
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

    private var weeklyForecastCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("map.weather.week_forecast"))
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(displayedDailyForecast.enumerated()), id: \.element.id) { index, day in
                        dayCarouselCard(day: day, isSelected: index == selectedDayIndex)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDayIndex = index
                                }
                            }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func dayCarouselCard(day: WeatherDailySnapshot, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.75))

            Image(systemName: resolvedSymbolName(day.symbolName))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.accent)

            Text("\(Int(day.highTemperatureCelsius.rounded()))°")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)

            Text("\(Int(day.lowTemperatureCelsius.rounded()))° • \(Int(day.precipitationChancePercent.rounded()))%")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.7))
        }
        .frame(width: 104, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(cardBackground(isSelected: isSelected))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func cardBackground(isSelected: Bool) -> some View {
        let gradient = LinearGradient(
            colors: isSelected
                ? [AppColors.accent.opacity(0.2), AppColors.primary.opacity(0.16)]
                : [Color.white.opacity(0.08), Color.black.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        if #available(iOS 26.0, *) {
            gradient
                .glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else {
            gradient
                .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var selectedDayDetailCard: some View {
        if let selectedDay {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(localized("map.weather.day_details"))
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)

                        Spacer()

                        Text(selectedDay.date, format: .dateTime.weekday(.wide))
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text.opacity(0.75))
                    }

                    HStack(spacing: 10) {
                        Image(systemName: resolvedSymbolName(selectedDay.symbolName))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.accent)

                        Text(selectedDay.conditionDescription)
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)
                    }

                    if selectedDay.precipitationAmountMillimeters > 0 {
                        detailRow(
                            label: localized("map.weather.metrics.rain_volume"),
                            value: "\(Int(selectedDay.precipitationAmountMillimeters.rounded())) mm",
                            symbol: "cloud.rain.fill"
                        )
                    }
                    if selectedDay.snowfallAmountCentimeters > 0 {
                        detailRow(
                            label: localized("map.weather.metrics.snow_volume"),
                            value: "\(Int(selectedDay.snowfallAmountCentimeters.rounded())) cm",
                            symbol: "cloud.snow.fill"
                        )
                    }
                    detailRow(
                        label: localized("map.weather.metrics.sunrise"),
                        value: formattedTime(selectedDay.sunrise),
                        symbol: "sunrise.fill"
                    )
                    detailRow(
                        label: localized("map.weather.metrics.sunset"),
                        value: formattedTime(selectedDay.sunset),
                        symbol: "sunset.fill"
                    )
                    detailRow(
                        label: localized("map.weather.metrics.dew_point"),
                        value: "\(Int(snapshot.current.dewPointCelsius.rounded()))°",
                        symbol: "thermometer.low"
                    )
                    detailRow(
                        label: localized("map.weather.metrics.cloud_cover"),
                        value: "\(Int(snapshot.current.cloudCoverPercent.rounded()))%",
                        symbol: "cloud.fill"
                    )
                }
            }
        }
    }

    private func detailRow(label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundColor(AppColors.accent)
                .frame(width: 16)

            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.72))

            Spacer()

            Text(value)
                .font(AppFonts.subheadline())
                .foregroundColor(AppColors.text)
        }
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var metricsGrid: some View {
        let items: [(String, String, String)] = [
            (localized("map.weather.metrics.feels_like"), "\(Int(snapshot.current.apparentTemperatureCelsius.rounded()))°", "thermometer"),
            (localized("map.weather.metrics.humidity"), "\(Int(snapshot.current.humidityPercent.rounded()))%", "humidity.fill"),
            (localized("map.weather.metrics.wind"), "\(Int(snapshot.current.windSpeedKilometersPerHour.rounded())) km/h", "wind"),
            ("UV", "\(Int(snapshot.current.uvIndex.rounded()))", "sun.max.fill"),
            (localized("map.weather.metrics.visibility"), "\(Int(snapshot.current.visibilityKilometers.rounded())) km", "eye.fill"),
            (localized("map.weather.metrics.pressure"), "\(Int(snapshot.current.pressureHPa.rounded())) hPa", "gauge")
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
                Text(localized("map.weather.today_temperature"))
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
                Text(localized("map.weather.today_rain_chance"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(snapshot.hourly.prefix(24)) { hour in
                    BarMark(
                        x: .value("Hour", hour.date),
                        y: .value("Chance (%)", hour.precipitationChancePercent)
                    )
                    .foregroundStyle(AppColors.accent)
                }
                .frame(height: 160)
            }
        }
    }

    private var weeklyTemperatureChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("map.weather.week_trend"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(snapshot.daily.prefix(7)) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("High", day.highTemperatureCelsius)
                    )
                    .foregroundStyle(AppColors.accent)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Low", day.lowTemperatureCelsius)
                    )
                    .foregroundStyle(AppColors.accent.opacity(0.6))
                    .symbol(.square)
                }
                .frame(height: 180)
            }
        }
    }

    private func resolvedSymbolName(_ symbolName: String) -> String {
        if UIImage(systemName: symbolName) != nil {
            return symbolName
        }
        return "cloud.sun.fill"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
