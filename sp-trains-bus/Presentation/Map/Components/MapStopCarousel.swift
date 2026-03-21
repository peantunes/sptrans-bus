import SwiftUI

struct MapStopCarousel: View {
    let items: [MapStopItem]
    let onSelect: (Stop) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button(action: { onSelect(item.stop) }) {
                            MapStopCard(item: item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

struct MapStopItem: Identifiable {
    let id: Int
    let stop: Stop
    let distanceMeters: Double
}

private struct MapStopCard: View {
    let item: MapStopItem

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 34, height: 34)

                        Image(systemName: stopSymbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text(distanceText)
                        .font(AppFonts.caption().bold())
                        .foregroundColor(.primary.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.22))
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.stop.stopName)
                        .font(AppFonts.title3().bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 2)

                    HStack(spacing: 8) {
                        if !item.stop.stopCode.isEmpty {
                            infoTag(title: "#\(item.stop.stopCode)")
                        }

                        if item.stop.wheelchairBoarding == 1 {
                            infoTag(title: localized("map.carousel.accessible"), systemImage: "figure.roll")
                        }
                    }
//                    Text(item.stop.transportType.name)
                    Text(localized("map.carousel.tap_arrivals"))
                        .font(AppFonts.caption())
                        .foregroundColor(.primary.opacity(0.78))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.primary.opacity(0.28),
                                    AppColors.primary.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.primary.opacity(0.6), lineWidth: 1)
                )
            }
            .frame(width: 220, alignment: .leading)
        }
    }

    private var stopSymbolName: String {
        let routes = (item.stop.routes ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if routes.contains("metro") || routes.contains("cptm") || routes.contains("train") {
            return "tram.fill"
        }

        return "bus.fill"
    }

    private var distanceText: String {
        if item.distanceMeters < 1000 {
            return String(format: localized("map.carousel.distance_m_format"), Int(item.distanceMeters))
        }

        return String(format: localized("map.carousel.distance_km_format"), item.distanceMeters / 1000)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @ViewBuilder
    private func infoTag(title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(AppFonts.caption2().bold())
        }
        .foregroundColor(.white.opacity(0.86))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.2))
        )
    }
}

#Preview {
    MapStopCarousel(
        items: [
            MapStopItem(
                id: 1,
                stop: Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561, longitude: -46.656), stopSequence: 1, routes: "METRÔ", stopCode: "PAU001", wheelchairBoarding: 1),
                distanceMeters: 320
            ),
            MapStopItem(
                id: 2,
                stop: Stop(stopId: 2, stopName: "Rua Augusta, 500", location: Location(latitude: -23.555, longitude: -46.651), stopSequence: 2, routes: "CPTM", stopCode: "AUG001", wheelchairBoarding: 0),
                distanceMeters: 840
            )
        ],
        onSelect: { _ in }
    )
}
