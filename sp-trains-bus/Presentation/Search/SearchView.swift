import SwiftUI
import MapKit

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    let dependencies: AppDependencies
    @State private var selectedStop: Stop?

    init(viewModel: SearchViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedPlaceName = viewModel.selectedPlaceName {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stops near")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Text(selectedPlaceName)
                        .font(AppFonts.title2())
                        .foregroundColor(AppColors.text)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Search a location")
                        .font(AppFonts.title2())
                        .foregroundColor(AppColors.text)

                    Text("Find stops around any address or landmark.")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if viewModel.isSearchingLocation || viewModel.isLoadingStops {
                HStack {
                    Spacer()
                    LoadingView()
                    Spacer()
                }
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage) {
                    Task {
                        await viewModel.submitSearch()
                    }
                }
            } else if viewModel.nearbyStops.isEmpty, !viewModel.searchText.isEmpty {
                Text("No stops found near \"\(viewModel.searchText)\".")
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text.opacity(0.7))
                    .padding(.horizontal)
            } else {
                List(viewModel.nearbyStops, id: \.stopId) { stop in
                    Button(action: {
                        selectedStop = stop
                    }) {
                        SearchResultRow(stop: stop, distance: viewModel.distanceToStop(stop))
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search Places")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search places")
        .searchSuggestions {
            ForEach(viewModel.searchSuggestions, id: \.stableIdentifier) { suggestion in
                Button(action: {
                    Task {
                        await viewModel.selectSuggestion(suggestion)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }
                    }
                }
            }
        }
        .onSubmit(of: .search) {
            Task {
                await viewModel.submitSearch()
            }
        }
        .sheet(item: $selectedStop) { stop in
            StopDetailView(viewModel: StopDetailViewModel(
                stop: stop,
                getArrivalsUseCase: dependencies.getArrivalsUseCase,
                getTripRouteUseCase: dependencies.getTripRouteUseCase,
                getRouteShapeUseCase: dependencies.getRouteShapeUseCase,
                storageService: dependencies.storageService
            ))
        }
    }
}

#Preview {
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] {
            return [
                Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP-1234", wheelchairBoarding: 0),
                Stop(stopId: 2, stopName: "Av. Paulista, 2000", location: Location(latitude: -23.562414, longitude: -46.657166), stopSequence: 2, stopCode: "SP-5678", wheelchairBoarding: 0)
            ]
        }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { return [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { return [] }
        func getTrip(tripId: String) async throws -> TripStop { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
    }

    class MockLocationService: LocationServiceProtocol {
        func requestLocationPermission() {}
        func getCurrentLocation() -> Location? { Location(latitude: -23.5505, longitude: -46.6333) }
        func startUpdatingLocation() {}
        func stopUpdatingLocation() {}
    }

    let mockRepository = MockTransitRepository()
    let mockLocation = MockLocationService()
    let getNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: mockRepository, locationService: mockLocation)
    let viewModel = SearchViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase)
    let dependencies = AppDependencies()

    return NavigationView {
        SearchView(viewModel: viewModel, dependencies: dependencies)
    }
}
