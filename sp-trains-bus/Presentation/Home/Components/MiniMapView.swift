import SwiftUI
import MapKit

struct MiniMapView: View {
    var stops: [Stop]
    let dependencies: AppDependencies // Inject dependencies

    @Binding var userLocation: Location?
    @State private var region: MKCoordinateRegion
    @State private var selectedStop: Stop? = nil

    init(userLocation: Binding<Location?>, stops: [Stop], dependencies: AppDependencies) {
        self._userLocation = userLocation
        self.stops = stops
        self.dependencies = dependencies

        _region = State(initialValue: MKCoordinateRegion(
            center: userLocation.wrappedValue?.toCLLocationCoordinate2D() ?? .saoPaulo, // Default to São Paulo
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: stops) { stop in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: stop.location.latitude, longitude: stop.location.longitude)) {
                StopAnnotation(stop: stop)
                .onTapGesture {
                    self.selectedStop = stop
                }
            }
        }
        .cornerRadius(10)
        .frame(height: 200)
        .onChange(of: userLocation) { _, newLocation in
            if let newLocation {
                region.center = newLocation.toCLLocationCoordinate2D()
            }
        }
        .fullScreenCover(item: $selectedStop) { selectedStop in
            StopDetailView(viewModel: StopDetailViewModel(
                stop: selectedStop,
                getArrivalsUseCase: dependencies.getArrivalsUseCase,
                getTripRouteUseCase: dependencies.getTripRouteUseCase,
                getRouteShapeUseCase: dependencies.getRouteShapeUseCase,
                storageService: dependencies.storageService
            ))
        }
    }
}

#Preview {
    MiniMapView(userLocation: .constant(Location(latitude: -23.5505, longitude: -46.6333)), stops: [
        Stop(stopId: 1, stopName: "Stop A", location: Location(latitude: -23.5510, longitude: -46.6340), stopSequence: 1, stopCode: "SA", wheelchairBoarding: 0),
        Stop(stopId: 2, stopName: "Stop B", location: Location(latitude: -23.5480, longitude: -46.6300), stopSequence: 2, stopCode: "SB", wheelchairBoarding: 0)
    ], dependencies: AppDependencies())
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
    static let saoPaulo = CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333)
}
