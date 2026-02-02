import SwiftUI
import CoreLocation

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    let dependencies: AppDependencies

    init(viewModel: HomeViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GreetingHeader(greeting: viewModel.getGreeting())
                    .padding(.top)

                QuickCommuteCard()
                    .padding(.horizontal)

                MiniMapView(userLocation: $viewModel.userLocation, stops: viewModel.nearbyStops, dependencies: dependencies)
                    .frame(height: 200)
                    .padding(.horizontal)

                FavoritesSection(favoriteStops: viewModel.favoriteStops, dependencies: dependencies)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear(perform: viewModel.loadData)
        .onAppear {
            if let location = viewModel.locationService.getCurrentLocation() {
                viewModel.userLocation = location
            }
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadData()
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
                Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0),
                Stop(stopId: 2, stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, stopCode: "SP2", wheelchairBoarding: 0)
            ]
        }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { return [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { return [] }
        func getTrip(tripId: String) async throws -> Trip { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
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

    class MockStorageService: StorageServiceProtocol {
        var favoriteValue: Bool = false
        
        func isFavorite(stopId: Int) -> Bool {
            return favoriteValue
        }
        
        func saveFavorite(stop: Stop) {}
        func removeFavorite(stop: Stop) {}
        func getFavoriteStops() -> [Stop] {
            return [
                Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0)
            ]
        }
        func saveHome(location: Location) {}
        func getHomeLocation() -> Location? { return nil }
        func saveWork(location: Location) {}
        func getWorkLocation() -> Location? { return nil }
    }

    let mockGetNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: MockTransitRepository(), locationService: MockLocationService())
    let mockLocationService = MockLocationService()
    let mockStorageService = MockStorageService()
    let viewModel = HomeViewModel(getNearbyStopsUseCase: mockGetNearbyStopsUseCase, locationService: mockLocationService, storageService: mockStorageService)
    viewModel.userLocation = Location(latitude: -23.5505, longitude: -46.6333) // Set a mock user location for preview
    let dependencies = AppDependencies()

    return HomeView(viewModel: viewModel, dependencies: dependencies)
}
