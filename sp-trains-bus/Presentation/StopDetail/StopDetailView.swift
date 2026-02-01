import SwiftUI

struct StopDetailView: View {
    @StateObject private var viewModel: StopDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: StopDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.15),
                        Color.purple.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Content
                        if viewModel.isLoading && viewModel.arrivals.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading arrivals...")
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.text.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if let errorMessage = viewModel.errorMessage, viewModel.arrivals.isEmpty {
                            ErrorView(message: errorMessage) {
                                viewModel.loadArrivals()
                            }
                        } else if let nextArrival = viewModel.arrivals.first {
                            // Next bus card
                            NextBusCard(arrival: nextArrival)
                                .padding(.horizontal)

                            // Upcoming arrivals list
                            UpcomingBusList(
                                arrivals: viewModel.arrivals,
                                onArrivalTap: { arrival in
                                    // Handle arrival tap if needed
                                }
                            )
                        } else {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "bus")
                                    .font(.system(size: 50))
                                    .foregroundColor(AppColors.text.opacity(0.3))

                                Text("No upcoming arrivals")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.text.opacity(0.6))

                                Text("Pull down to refresh or check back later")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await viewModel.refreshArrivals()
                }
            }
            .navigationTitle(viewModel.stop.stopName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Favorite button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                viewModel.toggleFavorite()
                            }
                        }) {
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .font(.title3)
                                .foregroundColor(viewModel.isFavorite ? .red : AppColors.text.opacity(0.6))
                                .scaleEffect(viewModel.isFavorite ? 1.1 : 1.0)
                        }

                        // Stop code
                        if !viewModel.stop.stopCode.isEmpty {
                            Text("#\(viewModel.stop.stopCode)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }
                    }
                }
            }
            .onAppear(perform: viewModel.loadArrivals)
            .onAppear(perform: viewModel.startRefreshingArrivals)
            .onDisappear(perform: viewModel.stopRefreshingArrivals)
        }
    }
}

#Preview {
    // Mock dependencies for Preview
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { return [] }
        func getArrivals(stopId: String, limit: Int) async throws -> [Arrival] {
            return [
                Arrival(tripId: "123", routeId: "6338-10", routeShortName: "6338-10", routeLongName: "Term. Pq. D. Pedro II", headsign: "Terminal Bandeira", arrivalTime: "10:30", departureTime: "10:30", stopId: "1", stopSequence: 1, routeType: 3, routeColor: "509E2F", routeTextColor: "FFFFFF", frequency: 15, waitTime: 3),
                Arrival(tripId: "124", routeId: "609P-10", routeShortName: "609P-10", routeLongName: "Lapa - Centro", headsign: "Jardim Paulista", arrivalTime: "10:45", departureTime: "10:45", stopId: "1", stopSequence: 2, routeType: 3, routeColor: "2196F3", routeTextColor: "FFFFFF", frequency: nil, waitTime: 12),
                Arrival(tripId: "125", routeId: "508M-10", routeShortName: "508M-10", routeLongName: "Vila Mariana", headsign: "Parque Ibirapuera", arrivalTime: "11:00", departureTime: "11:00", stopId: "1", stopSequence: 3, routeType: 3, routeColor: "9C27B0", routeTextColor: "FFFFFF", frequency: 20, waitTime: 25)
            ]
        }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { return [] }
        func getTrip(tripId: String) async throws -> Trip { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
    }

    class MockStorageService: StorageServiceProtocol {
        private var favorites: [Stop] = []
        func saveFavorite(stop: Stop) { favorites.append(stop) }
        func removeFavorite(stop: Stop) { favorites.removeAll { $0.stopId == stop.stopId } }
        func isFavorite(stopId: String) -> Bool { favorites.contains { $0.stopId == stopId } }
        func getFavoriteStops() -> [Stop] { favorites }
        func saveHome(location: Location) {}
        func getHomeLocation() -> Location? { nil }
        func saveWork(location: Location) {}
        func getWorkLocation() -> Location? { nil }
    }

    let sampleStop = Stop(stopId: "18848", stopName: "Clínicas", location: Location(latitude: -23.554022, longitude: -46.671108), stopSequence: 0, stopCode: "CLI001", wheelchairBoarding: 0)
    let mockGetArrivalsUseCase = GetArrivalsUseCase(transitRepository: MockTransitRepository())
    let mockStorageService = MockStorageService()
    let viewModel = StopDetailViewModel(stop: sampleStop, getArrivalsUseCase: mockGetArrivalsUseCase, storageService: mockStorageService)

    return StopDetailView(viewModel: viewModel)
}
