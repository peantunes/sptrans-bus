import SwiftUI
import MapKit

struct MiniMapView: View {
    var userLocation: CLLocationCoordinate2D?
    var stops: [Stop]

    @State private var region: MKCoordinateRegion

    init(userLocation: CLLocationCoordinate2D?, stops: [Stop]) {
        self.userLocation = userLocation
        self.stops = stops
        _region = State(initialValue: MKCoordinateRegion(
            center: userLocation ?? CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), // Default to São Paulo
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: stops) { stop in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.location.latitude, longitude: stop.location.longitude)) {
                VStack {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.blue)
                        .clipShape(Circle())
                    Text(stop.stopName)
                        .font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cornerRadius(10)
        .frame(height: 200)
        .onChange(of: userLocation) { oldLocation, newLocation in
            if let newLocation = newLocation {
                region.center = newLocation
            }
        }
    }
}

#Preview {
    MiniMapView(userLocation: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), stops: [
        Stop(stopId: 1, stopName: "Stop A", location: Location(latitude: -23.5510, longitude: -46.6340), stopSequence: 1, stopCode: "SA", wheelchairBoarding: 0),
        Stop(stopId: 2, stopName: "Stop B", location: Location(latitude: -23.5480, longitude: -46.6300), stopSequence: 2, stopCode: "SB", wheelchairBoarding: 0)
    ])
}
