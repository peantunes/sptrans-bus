import SwiftUI
import CoreLocation

struct NearbyStopsSection: View {
    let stops: [Stop]
    let userLocation: Location?
    let onSelectStop: (Stop) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Stops")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                Text("\(stops.count)")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.text.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            if stops.isEmpty {
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.text.opacity(0.4))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No nearby stops yet")
                                .font(AppFonts.subheadline())
                                .foregroundColor(AppColors.text)

                            Text("Enable location to see stops around you")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal)
            } else {
                GlassCard {
                    VStack(spacing: 12) {
                        ForEach(stops) { stop in
                            Button(action: { onSelectStop(stop) }) {
                                NearbyStopRow(
                                    stop: stop,
                                    distanceText: distanceText(for: stop)
                                )
                            }
                            .buttonStyle(.plain)

                            if stop.id != stops.last?.id {
                                Divider()
                                    .background(AppColors.text.opacity(0.1))
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func distanceText(for stop: Stop) -> String? {
        guard let userLocation else { return nil }

        let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stopLocation = CLLocation(latitude: stop.location.latitude, longitude: stop.location.longitude)
        let meters = user.distance(from: stopLocation)

        if meters < 1000 {
            return "\(Int(meters)) m"
        }

        return String(format: "%.1f km", meters / 1000)
    }
}

private struct NearbyStopRow: View {
    let stop: Stop
    let distanceText: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 32, height: 32)
                .background(AppColors.primary.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.stopName)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let distanceText {
                        Text(distanceText)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }

                    if !stop.stopCode.isEmpty {
                        Text("#\(stop.stopCode)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.text.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NearbyStopsSection(
        stops: [
            Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, routes: "METRÔ", stopCode: "SP1", wheelchairBoarding: 0),
            Stop(stopId: 2, stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, routes: "XXX", stopCode: "SP2", wheelchairBoarding: 0)
        ],
        userLocation: Location(latitude: -23.5505, longitude: -46.6333),
        onSelectStop: { _ in }
    )
    .padding()
}
