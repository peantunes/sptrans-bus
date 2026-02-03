import SwiftUI

struct WeatherSummaryCard: View {
    let city: String
    let temperature: Int
    let condition: String
    let high: Int
    let low: Int
    let precipitationChance: Int
    let feelsLike: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Weather")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Spacer()

                    Image(systemName: "sun.max.fill")
                        .foregroundColor(AppColors.accent)
                }

                Text(city)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))

                Text("\(temperature)°")
                    .font(AppFonts.largeTitle())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)

                Text(condition)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text.opacity(0.75))

                HStack(spacing: 12) {
                    Label("H \(high)°", systemImage: "arrow.up")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Label("L \(low)°", systemImage: "arrow.down")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }

                HStack(spacing: 12) {
                    Label("\(precipitationChance)%", systemImage: "drop.fill")
                        .font(AppFonts.caption2())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Label("Feels \(feelsLike)°", systemImage: "thermometer")
                        .font(AppFonts.caption2())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    WeatherSummaryCard(
        city: "São Paulo",
        temperature: 26,
        condition: "Partly Cloudy",
        high: 28,
        low: 20,
        precipitationChance: 20,
        feelsLike: 27
    )
    .padding()
}
