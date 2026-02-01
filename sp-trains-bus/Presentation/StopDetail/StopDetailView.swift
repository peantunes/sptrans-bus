import SwiftUI

struct StopDetailView: View {
    @StateObject private var viewModel: StopDetailViewModel

    init(viewModel: StopDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.stop.stopName)
                    .font(AppFonts.largeTitle())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadArrivals()
                    }
                } else if let nextArrival = viewModel.arrivals.first {
                    NextBusCard(arrival: nextArrival, routeColorString: "CCDD00", routeTextColorString: "FFFFFF")
                        .padding(.horizontal)
                } else {
                    Text("No upcoming arrivals.")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.7))
                        .padding(.horizontal)
                }

                UpcomingBusList(arrivals: viewModel.arrivals)
                    .padding(.bottom)
            }
        }
        .refreshable {
            viewModel.loadArrivals()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.loadArrivals)
        .onAppear(perform: viewModel.startRefreshingArrivals)
        .onDisappear(perform: viewModel.stopRefreshingArrivals)
    }
}

#Preview {
    // Mock dependencies for Preview
    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { return [] }
        func getArrivals(stopId: String, limit: Int) async throws -> [Arrival] {
            return [
                Arrival(tripId: "123", arrivalTime: "10:30", departureTime: "10:30", stopId: "1", stopSequence: 1, stopHeadsign: "Terminal Bandeira", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", frequency: nil, waitTime: 5),
                Arrival(tripId: "124", arrivalTime: "10:45", departureTime: "10:45", stopId: "1", stopSequence: 2, stopHeadsign: "Jardim Paulista", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", frequency: nil, waitTime: 20),
                Arrival(tripId: "125", arrivalTime: "11:00", departureTime: "11:00", stopId: "1", stopSequence: 3, stopHeadsign: "Parque Ibirapuera", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", frequency: nil, waitTime: 35)
            ]
        }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { return [] }
        func getTrip(tripId: String) async throws -> Trip { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { fatalError() }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { return [] }
    }

    let sampleStop = Stop(stopId: "18848", stopName: "Clínicas", location: Location(latitude: -23.554022, longitude: -46.671108), stopSequence: 0, stopCode: "", wheelchairBoarding: 0)
    let mockGetArrivalsUseCase = GetArrivalsUseCase(transitRepository: MockTransitRepository())
    let viewModel = StopDetailViewModel(stop: sampleStop, getArrivalsUseCase: mockGetArrivalsUseCase)

    return NavigationView {
        StopDetailView(viewModel: viewModel)
    }
}
