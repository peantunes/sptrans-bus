import Foundation

class AppDependencies {
    let apiClient: APIClient
    let transitRepository: TransitRepositoryProtocol
    let locationService: LocationServiceProtocol
    let storageService: StorageServiceProtocol

    let getNearbyStopsUseCase: GetNearbyStopsUseCase
    let getArrivalsUseCase: GetArrivalsUseCase
    let searchStopsUseCase: SearchStopsUseCase
    let getTripRouteUseCase: GetTripRouteUseCase
    let getRouteShapeUseCase: GetRouteShapeUseCase
    let getMetroStatusUseCase: GetMetroStatusUseCase

    let homeViewModel: HomeViewModel
    let searchViewModel: SearchViewModel
    let systemStatusViewModel: SystemStatusViewModel
    let mapExplorerViewModel: MapExplorerViewModel

    init() {
        // Infrastructure Layer
        apiClient = APIClient()
        transitRepository = TransitAPIRepository(apiClient: apiClient)
        locationService = CoreLocationService()
        storageService = UserDefaultsStorageService()

        // Application Layer - Use Cases
        getNearbyStopsUseCase = GetNearbyStopsUseCase(transitRepository: transitRepository, locationService: locationService)
        getArrivalsUseCase = GetArrivalsUseCase(transitRepository: transitRepository)
        searchStopsUseCase = SearchStopsUseCase(transitRepository: transitRepository)
        getTripRouteUseCase = GetTripRouteUseCase(transitRepository: transitRepository)
        getRouteShapeUseCase = GetRouteShapeUseCase(transitRepository: transitRepository)
        getMetroStatusUseCase = GetMetroStatusUseCase()

        // Presentation Layer - ViewModels
        homeViewModel = HomeViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService, storageService: storageService)
        searchViewModel = SearchViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase)
        systemStatusViewModel = SystemStatusViewModel(getMetroStatusUseCase: getMetroStatusUseCase)
        mapExplorerViewModel = MapExplorerViewModel(getNearbyStopsUseCase: getNearbyStopsUseCase, locationService: locationService)
    }
}
