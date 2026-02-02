import SwiftUI
import MapKit

struct MapExplorerView: View {
    @StateObject private var viewModel: MapExplorerViewModel
    @State private var selectedFilter: TransitFilter = .bus // Default filter
    let dependencies: AppDependencies // Inject dependencies

    init(viewModel: MapExplorerViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                FilterChips(selectedFilter: $selectedFilter)
                    .padding(.vertical, 5)

                TransitMapView(region: $viewModel.region, stops: viewModel.stops, dependencies: dependencies)
                    .edgesIgnoringSafeArea(.bottom)
            }

            // Floating buttons overlay
            VStack {
                Spacer()

                HStack {
                    // Center on user location button
                    Button(action: {
                        viewModel.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Refresh button (appears when region changes)
                    if viewModel.showRefreshButton {
                        Button(action: {
                            Task {
                                await viewModel.refreshStops()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Search this area")
                                    .font(AppFonts.subheadline())
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Placeholder for balance (invisible)
                    Color.clear
                        .frame(width: 44, height: 44)
                        .padding(.trailing, 16)
                }
                .padding(.bottom, 24)
            }

            // Loading indicator
            if viewModel.isLoading {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }

            // Error view
            if let errorMessage = viewModel.errorMessage, viewModel.stops.isEmpty {
                ErrorView(message: errorMessage) {
                    viewModel.loadStopsInVisibleRegion()
                }
            }
        }
        .navigationTitle("Map Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.loadStopsInVisibleRegion)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showRefreshButton)
    }
}

#Preview {
    // Mock dependencies for Preview
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
            return [
                Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561, longitude: -46.656), stopSequence: 1, stopCode: "PAU001", wheelchairBoarding: 1),
                Stop(stopId: 2, stopName: "Rua Augusta, 500", location: Location(latitude: -23.555, longitude: -46.651), stopSequence: 2, stopCode: "AUG001", wheelchairBoarding: 0),
                Stop(stopId: 3, stopName: "Consolação", location: Location(latitude: -23.557, longitude: -46.660), stopSequence: 3, stopCode: "CON001", wheelchairBoarding: 1)
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
    let dependencies = AppDependencies()

    return NavigationView {
        MapExplorerView(viewModel: viewModel, dependencies: dependencies)
    }
}
