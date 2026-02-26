import SwiftUI
import UIKit

struct MapWeatherButton: View {
    let snapshot: WeatherSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: resolvedSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text("\(Int(snapshot.current.temperatureCelsius.rounded()))°")
                    .font(AppFonts.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("map.weather.open_details_accessibility"))
    }

    private var resolvedSymbolName: String {
        if UIImage(systemName: snapshot.current.symbolName) != nil {
            return snapshot.current.symbolName
        }
        return "cloud.sun.fill"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
