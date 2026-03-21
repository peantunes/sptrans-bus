import SwiftUI
import UIKit

struct MapWeatherButton: View {
    let snapshot: WeatherSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 8) {
                    Image(systemName: resolvedSymbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    
                    Text("\(Int(snapshot.current.temperatureCelsius.rounded()))°")
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)
                }
            }
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
