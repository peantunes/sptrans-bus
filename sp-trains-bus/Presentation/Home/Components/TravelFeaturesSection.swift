import SwiftUI

struct TravelFeaturesSection: View {
    let features: [TravelFeature]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Tools")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(features) { feature in
                    FeatureCard(feature: feature)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TravelFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

private struct FeatureCard: View {
    let feature: TravelFeature

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: feature.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(feature.tint)
                    .frame(width: 32, height: 32)
                    .background(feature.tint.opacity(0.15))
                    .clipShape(Circle())

                Text(feature.title)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)

                Text(feature.subtitle)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TravelFeaturesSection(
        features: [
            TravelFeature(title: "Live Arrivals", subtitle: "Next bus and train ETAs", systemImage: "clock.badge.checkmark", tint: AppColors.primary),
            TravelFeature(title: "Service Alerts", subtitle: "Disruptions and line status", systemImage: "exclamationmark.triangle.fill", tint: AppColors.statusWarning),
            TravelFeature(title: "Accessibility", subtitle: "Elevators and ramps", systemImage: "figure.roll", tint: AppColors.accent),
            TravelFeature(title: "Bike + Walk", subtitle: "First/last mile tips", systemImage: "figure.walk.circle", tint: AppColors.secondary)
        ]
    )
}
