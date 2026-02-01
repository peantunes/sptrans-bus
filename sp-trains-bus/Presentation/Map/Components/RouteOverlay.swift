import SwiftUI
import MapKit

struct RouteOverlay: View {
    let locations: [Location]

    var body: some View {
        MapPolyline(coordinates: locations.map { $0.toCLLocationCoordinate2D() })
            .stroke(AppColors.accent, lineWidth: 5)
    }
}

#Preview {
    @State var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    let sampleLocations = [
        Location(latitude: -23.561414, longitude: -46.656166),
        Location(latitude: -23.560000, longitude: -46.650000),
        Location(latitude: -23.553000, longitude: -46.660000)
    ]
    return Map(coordinateRegion: $region) {
        RouteOverlay(locations: sampleLocations)
    }
}
