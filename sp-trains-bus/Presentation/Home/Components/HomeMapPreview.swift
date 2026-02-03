import SwiftUI
import MapKit

struct HomeMapPreview: View {
    let stops: [Stop]
    let userLocation: Location?
    let onOpenMap: () -> Void

    @State private var region: MKCoordinateRegion

    init(stops: [Stop], userLocation: Location?, onOpenMap: @escaping () -> Void) {
        self.stops = stops
        self.userLocation = userLocation
        self.onOpenMap = onOpenMap
        _region = State(initialValue: MKCoordinateRegion(
            center: userLocation?.toCLLocationCoordinate2D() ?? .saoPaulo,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        ))
    }

    var body: some View {
        Button(action: onOpenMap) {
            ZStack(alignment: .topLeading) {
                Map(
                    coordinateRegion: $region,
                    interactionModes: [],
                    showsUserLocation: false,
                    annotationItems: stops
                ) { stop in
                    MapAnnotation(coordinate: stop.location.toCLLocationCoordinate2D()) {
                        Circle()
                            .fill(AppColors.primary.opacity(0.85))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                    }
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Explore the map")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Text("Tap to open the live map")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                    Text("Open Map")
                }
                .font(AppFonts.callout())
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColors.primary.opacity(0.85))
                .clipShape(Capsule())
                .padding(12)
            }
            .frame(height: 200)
        }
        .buttonStyle(.plain)
        .onChange(of: userLocation) { _, newLocation in
            if let newLocation {
                region.center = newLocation.toCLLocationCoordinate2D()
            }
        }
    }
}

#Preview {
    HomeMapPreview(
        stops: [
            Stop(stopId: 1, stopName: "Stop A", location: Location(latitude: -23.5510, longitude: -46.6340), stopSequence: 1, stopCode: "SA", wheelchairBoarding: 0),
            Stop(stopId: 2, stopName: "Stop B", location: Location(latitude: -23.5480, longitude: -46.6300), stopSequence: 2, stopCode: "SB", wheelchairBoarding: 0)
        ],
        userLocation: Location(latitude: -23.5505, longitude: -46.6333),
        onOpenMap: {}
    )
    .padding()
}
