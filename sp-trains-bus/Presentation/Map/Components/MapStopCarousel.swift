import SwiftUI

struct MapStopCarousel: View {
    let items: [MapStopItem]
    let onSelect: (Stop) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nearby to map center")
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)

                Spacer()

                Text("\(items.count)")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.text.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

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
//        .background(
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    AppColors.background.opacity(0.95),
//                    AppColors.background.opacity(0.85)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .ignoresSafeArea()
//        )
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(6)
                        .glassIfAvailble()
//                        .background(AppColors.primary.opacity(0.12))
                        .clipShape(Circle())

                    Spacer()

                    Text(distanceText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }

                Text(item.stop.stopName)
                    .font(AppFonts.subheadline().bold())
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !item.stop.stopCode.isEmpty {
                        Text("#\(item.stop.stopCode)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }

                    if item.stop.wheelchairBoarding == 1 {
                        Label("Accessible", systemImage: "figure.roll")
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }

                Text("Tap for arrivals")
                    .font(AppFonts.caption2())
                    .foregroundColor(AppColors.text.opacity(0.5))
            }
            .frame(width: 200, alignment: .leading)
        }
    }

    private var distanceText: String {
        if item.distanceMeters < 1000 {
            return "\(Int(item.distanceMeters)) m"
        }

        return String(format: "%.1f km", item.distanceMeters / 1000)
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

extension View {
    @ViewBuilder
    func glassIfAvailble() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.plain)
        }
    }
}
