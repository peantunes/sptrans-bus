import SwiftUI

struct FavoritesSection: View {
    let favoriteStops: [Stop]
    let onSelectStop: (Stop) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Favorites")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                if !favoriteStops.isEmpty {
                    Text("\(favoriteStops.count)")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.text.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            if favoriteStops.isEmpty {
                // Empty state
                GlassCard {
                    HStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.text.opacity(0.4))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No favorites yet")
                                .font(AppFonts.subheadline())
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.text)

                            Text("Tap the heart icon on any stop to add it here")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(favoriteStops, id: \.stopId) { stop in
                            Button(action: { onSelectStop(stop) }) {
                                FavoriteStopCard(stop: stop)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview("With Favorites") {
    let sampleStops = [
        Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, routes: "METRÔ", stopCode: "SP1", wheelchairBoarding: 0),
        Stop(stopId: 2, stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, routes: "CPTM", stopCode: "SP2", wheelchairBoarding: 0),
        Stop(stopId: 3, stopName: "Metro Consolacao", location: Location(latitude: -23.553000, longitude: -46.660000), stopSequence: 3, routes: "XXX", stopCode: "SP3", wheelchairBoarding: 0)
    ]
    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        FavoritesSection(favoriteStops: sampleStops, onSelectStop: { _ in })
    }
}

#Preview("Empty State") {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        FavoritesSection(favoriteStops: [], onSelectStop: { _ in })
    }
}
