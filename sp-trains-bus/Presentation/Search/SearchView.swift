import SwiftUI
import MapKit

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @ObservedObject private var conditions: JourneyConditionsStore
    let dependencies: AppDependencies
    @FocusState private var focusedField: Field?
    @State private var directOnly = false
    private enum Field: Hashable { case origin, destination }

    init(viewModel: SearchViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _conditions = ObservedObject(wrappedValue: dependencies.journeyConditions)
        self.dependencies = dependencies
    }

    private var directCount: Int {
        viewModel.alternatives.filter { $0.type != .walk && $0.transfers == 0 }.count
    }
    private var visibleAlternatives: [TripPlanAlternative] {
        directOnly ? viewModel.alternatives.filter { $0.type != .walk && $0.transfers == 0 } : viewModel.alternatives
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                JourneyCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(spacing: 14) {
                                locationField(.origin, title: "From", text: $viewModel.originQuery, symbol: "circle.fill")
                                Divider().padding(.leading, 30)
                                locationField(.destination, title: "To", text: $viewModel.destinationQuery, symbol: "mappin.and.ellipse")
                            }
                            Button {
                                focusedField = nil
                                viewModel.swapLocations()
                            } label: {
                                Image(systemName: "arrow.up.arrow.down").font(.title3.weight(.semibold))
                                    .padding(13).background(AppColors.primary.opacity(0.12), in: Circle())
                            }
                            .accessibilityLabel("Swap origin and destination")
                            .accessibilityIdentifier("planner.swap")
                        }

                        if let field = focusedField {
                            suggestions(for: field)
                        }
                        Button {
                            focusedField = nil
                            viewModel.setOriginToCurrentLocation()
                        } label: {
                            Label("Use current location", systemImage: "location.fill").font(.subheadline)
                        }
                        Divider()
                        HStack {
                            Label("Departure", systemImage: "clock").font(.headline)
                            Spacer()
                            Picker("Departure", selection: $viewModel.useDepartureTime) {
                                Text("Now").tag(false)
                                Text("Choose time").tag(true)
                            }.pickerStyle(.menu).labelsHidden()
                            .accessibilityIdentifier("planner.departureMode")
                        }
                        if viewModel.useDepartureTime {
                            DatePicker("Leave at", selection: $viewModel.departureDate, displayedComponents: [.date, .hourAndMinute])
                                .environment(\.timeZone, TimeZone(identifier: "America/Sao_Paulo")!)
                                .accessibilityIdentifier("planner.departureDate")
                        }
                        Text("Times shown in São Paulo time.").font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("Journey preferences") {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Sort by", selection: $viewModel.rankingPriority) {
                                    Text("Arrive earliest").tag("arrives_first")
                                    Text("Shortest journey").tag("shortest")
                                    Text("Fewest transfers").tag("fewest_transfers")
                                    Text("Least walking").tag("least_walking")
                                    Text("Closest boarding stop").tag("closest_origin")
                                    Text("Closest arrival stop").tag("closest_destination")
                                }
                                Picker("Preferred maximum transfers", selection: $viewModel.maxTransfers) {
                                    ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                                }
                                Text("If no route is found, options with more transfers may appear.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 12)
                        }
                        Button(action: search) {
                            HStack {
                                if viewModel.isPlanning { ProgressView().tint(.white) }
                                Text(LocalizedStringKey(viewModel.isPlanning ? "Searching journeys…" : "Search journeys"))
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(AppColors.primary.opacity(viewModel.canPlan || viewModel.isPlanning ? 1 : 0.45), in: Capsule())
                        }
                        .disabled(!viewModel.canPlan)
                        .accessibilityIdentifier("planner.search")
                        if viewModel.isResolving {
                            Label("Finding location…", systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(.red)
                        .accessibilityIdentifier("planner.error")
                }
                results
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Plan a trip")
        .navigationBarTitleDisplayMode(.large)
        .tint(AppColors.primary)
        .onChange(of: viewModel.useDepartureTime) { _, newValue in
            if !newValue { viewModel.departNow() } else { viewModel.invalidateResults() }
        }
        .onChange(of: viewModel.departureDate) { _, _ in viewModel.invalidateResults() }
        .onChange(of: viewModel.rankingPriority) { _, _ in viewModel.invalidateResults() }
        .onChange(of: viewModel.maxTransfers) { _, _ in viewModel.invalidateResults() }
        .onAppear {
            dependencies.analyticsService.trackScreen(name: "SearchView", className: "SearchView")
            viewModel.fillOriginWithCurrentLocationIfEmpty()
        }
    }

    private func locationField(_ field: Field, title: LocalizedStringKey, text: Binding<String>, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppColors.primary).frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                TextField("Address or place", text: text)
                    .font(.body.weight(.medium)).focused($focusedField, equals: field)
                    .autocorrectionDisabled().submitLabel(.search)
                    .accessibilityIdentifier(field == .origin ? "planner.origin" : "planner.destination")
            }
        }
    }

    @ViewBuilder private func suggestions(for field: Field) -> some View {
        let values = field == .origin ? viewModel.originSuggestions : viewModel.destinationSuggestions
        if !values.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(values.prefix(6).enumerated()), id: \.offset) { _, suggestion in
                    Button {
                        Task {
                            if field == .origin { await viewModel.selectOriginSuggestion(suggestion) }
                            else { await viewModel.selectDestinationSuggestion(suggestion) }
                            if (field == .origin ? viewModel.originLocation : viewModel.destinationLocation) != nil {
                                focusedField = nil
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.title).font(.subheadline.weight(.medium))
                            Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    }.buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder private var results: some View {
        if viewModel.hasPlanned, let context = viewModel.resultContext {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Journey options").font(.title2.bold())
                    Text("\(context.originLabel) → \(context.destinationLabel)").font(.subheadline).foregroundStyle(.secondary)
                    Text(context.departure, format: .dateTime.day().month().hour().minute().timeZone(.specificName(.short)))
                        .environment(\.timeZone, TimeZone(identifier: "America/Sao_Paulo")!)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !viewModel.alternatives.isEmpty {
                    Picker("Journey options", selection: $directOnly) {
                        Text("All (\(viewModel.alternatives.count))").tag(false)
                        Text("Direct only (\(directCount))").tag(true)
                    }.pickerStyle(.segmented)
                }
                if visibleAlternatives.isEmpty {
                    ContentUnavailableView("No journeys found", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text(LocalizedStringKey(directOnly ? "Try all journeys to include transfers and walking." : "Try another departure time or nearby locations.")))
                }
                ForEach(visibleAlternatives) { alternative in
                    NavigationLink {
                        TripPlanDetailView(alternative: alternative,
                            originLocation: context.origin, destinationLocation: context.destination,
                            originLabel: context.originLabel, destinationLabel: context.destinationLabel,
                            dependencies: dependencies, departureDate: context.departure)
                    } label: {
                        JourneyOptionCard(alternative: alternative,
                            alerts: conditions.alerts(for: alternative),
                            statusUnavailable: conditions.statusUnavailable(for: alternative),
                            statusRefreshFailed: conditions.failed)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planner.result")
                }
                if conditions.isLoading { ProgressView("Checking rail conditions…").font(.caption) }
                if !viewModel.alternatives.isEmpty {
                    Text("Scheduled estimates. Live arrivals and reported line alerts are shown separately when available.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func search() {
        focusedField = nil
        directOnly = false
        Task {
            await viewModel.planTrip()
            if viewModel.alternatives.contains(where: { $0.vehicleLegs.contains(where: { $0.railSource != nil }) }) {
                await conditions.refresh()
            }
        }
    }
}
