import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    let dependencies: AppDependencies
    let onOpenMap: () -> Void
    let onOpenStatus: () -> Void

    @State private var selectedStop: Stop?

    init(
        viewModel: HomeViewModel,
        dependencies: AppDependencies,
        onOpenMap: @escaping () -> Void = {},
        onOpenStatus: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
        self.onOpenMap = onOpenMap
        self.onOpenStatus = onOpenStatus
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GreetingHeader(greeting: viewModel.getGreeting())
                    .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    WeatherSummaryCard(
                        city: "São Paulo",
                        temperature: 26,
                        condition: "Partly Cloudy",
                        high: 28,
                        low: 20,
                        precipitationChance: 20,
                        feelsLike: 27
                    )

                    QuickCommuteCard()
                }
                .padding(.horizontal)

                RailStatusSection(
                    items: [
                        RailStatusItem(
                            id: "metro",
                            title: "Metrô de SP",
                            status: "Normal",
                            detail: "All lines operating normally",
                            color: AppColors.statusNormal,
                            systemImage: "tram.fill"
                        ),
                        RailStatusItem(
                            id: "cptm",
                            title: "CPTM",
                            status: "Attention",
                            detail: "Speed restriction on Line 9",
                            color: AppColors.statusWarning,
                            systemImage: "train.side.front.car"
                        )
                    ],
                    onOpenStatus: onOpenStatus
                )

                TravelFeaturesSection(
                    features: [
                        TravelFeature(
                            title: "Live Arrivals",
                            subtitle: "Next bus and train ETAs",
                            systemImage: "clock.badge.checkmark",
                            tint: AppColors.primary
                        ),
                        TravelFeature(
                            title: "Service Alerts",
                            subtitle: "Disruptions and line status",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: AppColors.statusWarning
                        ),
                        TravelFeature(
                            title: "Accessibility",
                            subtitle: "Elevators and ramps",
                            systemImage: "figure.roll",
                            tint: AppColors.accent
                        ),
                        TravelFeature(
                            title: "Bike + Walk",
                            subtitle: "First and last mile tips",
                            systemImage: "figure.walk.circle",
                            tint: AppColors.secondary
                        )
                    ]
                )

                HomeMapPreview(stops: viewModel.nearbyStops, userLocation: viewModel.userLocation, onOpenMap: onOpenMap)
                    .padding(.horizontal)

                FavoritesSection(
                    favoriteStops: viewModel.favoriteStops,
                    onSelectStop: { selectedStop = $0 }
                )

                NearbyStopsSection(
                    stops: viewModel.nearbyStops,
                    userLocation: viewModel.userLocation,
                    onSelectStop: { selectedStop = $0 }
                )
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
        .sheet(item: $selectedStop) { stop in
            StopDetailView(
                viewModel: StopDetailViewModel(
                    stop: stop,
                    getArrivalsUseCase: dependencies.getArrivalsUseCase,
                    getTripRouteUseCase: dependencies.getTripRouteUseCase,
                    getRouteShapeUseCase: dependencies.getRouteShapeUseCase,
                    storageService: dependencies.storageService
                )
            )
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
        func getTrip(tripId: String) async throws -> TripStop { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
        func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
            return TripPlan(alternatives: [], rankingPriority: rankingPriority)
        }
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
