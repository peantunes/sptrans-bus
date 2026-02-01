import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    let dependencies: AppDependencies

    init(viewModel: SearchViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        VStack {
            SearchBar(text: $viewModel.searchText)
                .padding(.horizontal)

            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage) { 
                    viewModel.searchText = viewModel.searchText // Trigger re-search
                }
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                Text("No results found for \"\(viewModel.searchText)\"")
                    .foregroundColor(AppColors.text.opacity(0.7))
                    .padding()
            } else {
                List(viewModel.searchResults, id: \.stopId) { stop in
                    NavigationLink(destination: StopDetailView(viewModel: StopDetailViewModel(
                        stop: stop,
                        getArrivalsUseCase: dependencies.getArrivalsUseCase,
                        storageService: dependencies.storageService
                    ))) {
                        SearchResultRow(stop: stop)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Search Stops")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            TextField("Search for stops...", text: $text)
                .padding(8)
                .padding(.horizontal, 24)
                .background(AppColors.lightGray)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}

#Preview {
    // Mock dependencies for Preview
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { return [] }
        func getArrivals(stopId: String, limit: Int) async throws -> [Arrival] { return [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] {
            if query.lowercased().contains("paulista") {
                return [
                    Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP-1234", wheelchairBoarding: 0),
                    Stop(stopId: "2", stopName: "Av. Paulista, 2000", location: Location(latitude: -23.562414, longitude: -46.657166), stopSequence: 2, stopCode: "SP-5678", wheelchairBoarding: 0)
                ]
            } else {
                return []
            }
        }
        func getTrip(tripId: String) async throws -> Trip { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
    }

    class MockSearchStopsUseCase: SearchStopsUseCase {
        init() {
            super.init(transitRepository: MockTransitRepository())
        }
        override func execute(query: String, limit: Int = 10) async throws -> [Stop] {
            if query.lowercased().contains("paulista") {
                return [
                    Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP-1234", wheelchairBoarding: 0),
                    Stop(stopId: "2", stopName: "Av. Paulista, 2000", location: Location(latitude: -23.562414, longitude: -46.657166), stopSequence: 2, stopCode: "SP-5678", wheelchairBoarding: 0)
                ]
            } else {
                return []
            }
        }
    }

    let viewModel = SearchViewModel(searchStopsUseCase: MockSearchStopsUseCase())
    let dependencies = AppDependencies()

    return SearchView(viewModel: viewModel, dependencies: dependencies)
}
