import SwiftUI
import MapKit

struct MapExplorerView: View {
    @StateObject private var viewModel: MapExplorerViewModel
    @State private var selectedFilter: TransitFilter = .bus // Default filter

    init(viewModel: MapExplorerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            FilterChips(selectedFilter: $selectedFilter)
                .padding(.vertical, 5)

            TransitMapView(region: $viewModel.region, stops: viewModel.stops)
                .edgesIgnoringSafeArea(.all)
        }
        .navigationTitle("Map Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.loadStopsInVisibleRegion)
        .overlay(
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadStopsInVisibleRegion()
                    }
                }
            }
        )
    }
}

#Preview {
    // Mock dependencies for Preview
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
            return [
                Stop(stopId: 1, stopName: "Map Stop A", location: Location(latitude: -23.555, longitude: -46.635), stopSequence: 1, stopCode: "MSA", wheelchairBoarding: 0),
                Stop(stopId: 2, stopName: "Map Stop B", location: Location(latitude: -23.548, longitude: -46.630), stopSequence: 2, stopCode: "MSB", wheelchairBoarding: 0)
            ]
        }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { return [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { return [] }
        func getTrip(tripId: String) async throws -> Trip { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { return [] }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
    }

    class MockLocationService: LocationServiceProtocol {
        func requestLocationPermission() {}
        func getCurrentLocation() -> Location? {
            return Location(latitude: -23.5505, longitude: -46.6333)
        }
        func startUpdatingLocation() {}
        func stopUpdatingLocation() {}
    }

    let mockGetNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: MockTransitRepository(), locationService: MockLocationService())
    let mockLocationService = MockLocationService()
    let viewModel = MapExplorerViewModel(getNearbyStopsUseCase: mockGetNearbyStopsUseCase, locationService: mockLocationService)

    return MapExplorerView(viewModel: viewModel)
}
