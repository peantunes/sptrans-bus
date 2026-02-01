import SwiftUI
import MapKit

struct TransitMapView: View {
    @Binding var region: MKCoordinateRegion
    let stops: [Stop]
    let dependencies: AppDependencies // Inject dependencies

    @State private var selectedStop: Stop?
    @State private var isShowingStopDetail: Bool = false

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: stops) { stop in
            MapAnnotation(coordinate: stop.location.toCLLocationCoordinate2D()) {
                StopAnnotation(stop: stop)
                    .onTapGesture {
                        self.selectedStop = stop
                        self.isShowingStopDetail = true
                    }
            }
        }
        .sheet(isPresented: $isShowingStopDetail) {
            if let selectedStop = selectedStop {
                StopDetailView(viewModel: StopDetailViewModel(
                    stop: selectedStop,
                    getArrivalsUseCase: dependencies.getArrivalsUseCase,
                    storageService: dependencies.storageService
                ))
            }
        }
    }
}

//#Preview {
//    @State var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
//    let sampleStops = [
//        Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0),
//        Stop(stopId: "2", stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, stopCode: "SP2", wheelchairBoarding: 0)
//    ]
//    return TransitMapView(region: $region, stops: sampleStops)
//}
