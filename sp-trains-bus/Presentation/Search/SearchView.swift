import SwiftUI
import MapKit

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    let dependencies: AppDependencies
    @State private var activeField: ActiveField? = nil
    @State private var isCollapsed: Bool = false

    enum ActiveField {
        case origin
        case destination
    }

    init(viewModel: SearchViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isCollapsed {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCollapsed = false
                        }
                    }) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Route")
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.text.opacity(0.6))

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(AppColors.text.opacity(0.6))
                                }

                                Text("\(viewModel.originQuery) → \(viewModel.destinationQuery)")
                                    .font(AppFonts.subheadline())
                                    .foregroundColor(AppColors.text)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SearchLocationField(
                                title: "Origin",
                                placeholder: "Current location",
                                systemImage: "location.fill",
                                text: $viewModel.originQuery,
                                trailingTitle: "Use"
                            ) {
                                viewModel.setOriginToCurrentLocation()
                                hideKeyboard()
                            }
                            .onTapGesture { activeField = .origin }
                            .onChange(of: viewModel.originQuery) { _, _ in
                                activeField = .origin
                            }

                            SearchLocationField(
                                title: "Destination",
                                placeholder: "Search destination",
                                systemImage: "mappin.and.ellipse",
                                text: $viewModel.destinationQuery
                            )
                            .onTapGesture { activeField = .destination }
                            .onChange(of: viewModel.destinationQuery) { _, _ in
                                activeField = .destination
                            }

                            Button(action: {
                                hideKeyboard()
                                activeField = nil
                                viewModel.clearSuggestions()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCollapsed = true
                                }
                                Task {
                                    await viewModel.planTrip()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                    Text("Plan route")
                                }
                                .font(AppFonts.callout())
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if !isCollapsed, activeField == .origin, !viewModel.originSuggestions.isEmpty {
                    suggestionList(
                        title: "Origin suggestions",
                        suggestions: viewModel.originSuggestions,
                        onSelect: { suggestion in
                            Task {
                                await viewModel.selectOriginSuggestion(suggestion)
                                hideKeyboard()
                                activeField = nil
                            }
                        }
                    )
                }

                if !isCollapsed, activeField == .destination, !viewModel.destinationSuggestions.isEmpty {
                    suggestionList(
                        title: "Destination suggestions",
                        suggestions: viewModel.destinationSuggestions,
                        onSelect: { suggestion in
                            Task {
                                await viewModel.selectDestinationSuggestion(suggestion)
                                hideKeyboard()
                                activeField = nil
                            }
                        }
                    )
                }

                if viewModel.isPlanning {
                    HStack {
                        Spacer()
                        LoadingView()
                        Spacer()
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.planTrip()
                        }
                    }
                    .padding(.horizontal)
                }

                if !viewModel.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Best options")
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)
                            .padding(.horizontal)

                        ForEach(viewModel.alternatives) { alternative in
                            NavigationLink {
                                TripPlanDetailView(
                                    alternative: alternative,
                                    originLocation: viewModel.originLocation,
                                    destinationLocation: viewModel.destinationLocation,
                                    originLabel: viewModel.originQuery,
                                    destinationLabel: viewModel.destinationQuery,
                                    dependencies: dependencies
                                )
                            } label: {
                                JourneyOptionCard(alternative: alternative)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func suggestionList(
        title: String,
        suggestions: [MKLocalSearchCompletion],
        onSelect: @escaping (MKLocalSearchCompletion) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.6))
                .padding(.horizontal)

            GlassCard {
                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.stableIdentifier) { suggestion in
                        Button(action: { onSelect(suggestion) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(AppFonts.subheadline())
                                    .foregroundColor(AppColors.text)

                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.text.opacity(0.6))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        if suggestion.stableIdentifier != suggestions.last?.stableIdentifier {
                            Divider()
                                .background(AppColors.text.opacity(0.1))
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    class MockPlanTripUseCase: PlanTripUseCase {
        init() {
            super.init(transitRepository: MockTransitRepository())
        }
        override func execute(origin: Location, destination: Location, maxAlternatives: Int = 5, rankingPriority: String = "arrives_first") async throws -> TripPlan {
            TripPlan(alternatives: [
                TripPlanAlternative(type: .direct, departureTime: "08:10", arrivalTime: "08:55", legCount: 1, stopCount: 12, lineSummary: "1080-0"),
                TripPlanAlternative(type: .transfer, departureTime: "08:20", arrivalTime: "09:12", legCount: 2, stopCount: 18, lineSummary: "1080-0 > 9033-1")
            ], rankingPriority: "arrives_first")
        }
    }

    class MockLocationService: LocationServiceProtocol {
        func requestLocationPermission() {}
        func getCurrentLocation() -> Location? { Location(latitude: -23.5505, longitude: -46.6333) }
        func startUpdatingLocation() {}
        func stopUpdatingLocation() {}
    }

    class MockTransitRepository: TransitRepositoryProtocol {
        func getNearbyStops(location: Location, limit: Int) async throws -> [Stop] { [] }
        func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival] { [] }
        func searchStops(query: String, limit: Int) async throws -> [Stop] { [] }
        func getTrip(tripId: String) async throws -> TripStop { fatalError() }
        func getRoute(routeId: String) async throws -> Route { fatalError() }
        func getShape(shapeId: String) async throws -> [Location] { [] }
        func getAllRoutes(limit: Int, offset: Int) async throws -> [Route] { [] }
        func planTrip(origin: Location, destination: Location, maxAlternatives: Int, rankingPriority: String) async throws -> TripPlan {
            TripPlan(alternatives: [], rankingPriority: rankingPriority)
        }
    }

    let viewModel = SearchViewModel(planTripUseCase: MockPlanTripUseCase(), locationService: MockLocationService())
    let dependencies = AppDependencies()

    return NavigationView {
        SearchView(viewModel: viewModel, dependencies: dependencies)
    }
}
