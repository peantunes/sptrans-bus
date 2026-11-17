import SwiftUI
import MapKit
import Combine

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @ObservedObject private var conditions: JourneyConditionsStore
    let dependencies: AppDependencies
    @FocusState private var focusedField: Field?
    @State private var directOnly = false
    @State private var showsSavedRoutes = false
    @State private var premiumSheetSource: String?
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

    @State private var containerWidth: CGFloat = 0
    /// iPad landscape and other wide screens: form on the left, results on the right.
    private var isWide: Bool { containerWidth >= 900 }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) { formColumn }
                            .padding(20)
                    }
                    .frame(width: min(460, containerWidth * 0.42))
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if viewModel.hasPlanned { results } else { resultsPlaceholder }
                        }
                        .padding(20)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        formColumn
                        results
                    }
                    .padding(16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Plan a trip")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.primary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    focusedField = nil
                    showsSavedRoutes = true
                } label: {
                    Image(systemName: "bookmark")
                }
                .accessibilityLabel("Saved routes")
                .accessibilityIdentifier("planner.savedRoutes")
            }
        }
        .sheet(isPresented: $showsSavedRoutes) {
            SavedRoutesSheet(viewModel: viewModel) { route in
                showsSavedRoutes = false
                directOnly = false
                Task {
                    await viewModel.useRoute(route)
                    await refreshConditionsIfNeeded()
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $viewModel.premiumPrompt) { prompt in
            Alert(
                title: Text("Premium feature"),
                message: Text(LocalizedStringKey(prompt.messageKey)),
                primaryButton: .default(Text("See Premium")) {
                    showsSavedRoutes = false
                    premiumSheetSource = "planner_\(prompt.rawValue)"
                },
                secondaryButton: .cancel(Text("Not now"))
            )
        }
        .sheet(item: Binding(get: { premiumSheetSource.map(PremiumSource.init) }, set: { premiumSheetSource = $0?.id })) { source in
            PremiumSubscriptionSheet(analyticsService: dependencies.analyticsService, source: source.id) {
                viewModel.objectWillChange.send()
            }
        }
        .onChange(of: navigationCoordinator.plannerCommand) { _, command in
            guard let command else { return }
            navigationCoordinator.plannerCommand = nil
            switch command {
            case .newTrip:
                viewModel.clearForm()
                directOnly = false
                focusedField = .destination
            case .findDestination:
                focusedField = .destination
            case .savedRoutes:
                focusedField = nil
                showsSavedRoutes = true
            case .search:
                if viewModel.canPlan { search() }
            }
        }
        .onAppear {
            dependencies.analyticsService.trackScreen(name: "SearchView", className: "SearchView")
            viewModel.fillOriginWithCurrentLocationIfEmpty()
        }
    }

    @ViewBuilder private var formColumn: some View {
        PlannerHeroHeader(compact: isWide)
        placesCard
        whenCard
        searchButton
        if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(.red)
                .accessibilityIdentifier("planner.error")
        }
    }

    /// Wide screens before the first search: the results column is not left empty.
    private var resultsPlaceholder: some View {
        ImageBanner(imageName: "planner_results_ipiranga", height: 220) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your journey options appear here").font(.title3.bold())
                Text("Door to door by bus, Metro and CPTM, with every stop.").font(.subheadline).opacity(0.85)
            }
        }
    }

    // MARK: - Places

    private var placesCard: some View {
        JourneyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 0) {
                        placeRow(.origin, title: "From", text: $viewModel.originQuery, isFirst: true)
                        Divider().padding(.leading, 36)
                        placeRow(.destination, title: "To", text: $viewModel.destinationQuery, isFirst: false)
                    }
                    Button {
                        focusedField = nil
                        viewModel.swapLocations()
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.body.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(AppColors.primary.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Swap origin and destination")
                    .accessibilityIdentifier("planner.swap")
                }

                if let field = focusedField {
                    suggestions(for: field)
                }
                if viewModel.isResolving {
                    Label("Finding location…", systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        focusedField = nil
                        viewModel.setOriginToCurrentLocation()
                    } label: {
                        Label("Use current location", systemImage: "location.fill").font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    if viewModel.hasFormContent {
                        Button(role: .destructive) {
                            focusedField = nil
                            directOnly = false
                            viewModel.clearForm()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle").font(.subheadline.weight(.medium))
                        }
                        .accessibilityIdentifier("planner.clear")
                    }
                }
            }
        }
    }

    /// A place field on the same rail language as the journey's stop timeline.
    private func placeRow(_ field: Field, title: LocalizedStringKey, text: Binding<String>, isFirst: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PlaceRail(isFirst: isFirst)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("Address or place", text: text)
                        .font(.body.weight(.medium))
                        .focused($focusedField, equals: field)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { if viewModel.canPlan { search() } }
                        .accessibilityIdentifier(field == .origin ? "planner.origin" : "planner.destination")
                    if !text.wrappedValue.isEmpty {
                        Button {
                            viewModel.clearField(isOrigin: field == .origin)
                            focusedField = field
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear field")
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
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
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(.secondary).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title).font(.subheadline.weight(.medium))
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 34)
                }
            }
        }
    }

    // MARK: - When and preferences

    private var whenCard: some View {
        JourneyCard {
            VStack(spacing: 0) {
                settingRow(icon: "clock", title: "Departure") {
                    Menu {
                        Button {
                            viewModel.departNow()
                        } label: {
                            if viewModel.useDepartureTime { Text("Leave now") } else { Label("Leave now", systemImage: "checkmark") }
                        }
                        Button {
                            viewModel.chooseDepartureTime()
                        } label: {
                            if !viewModel.isPremium {
                                Label("Choose time", systemImage: "lock.fill")
                            } else if viewModel.useDepartureTime {
                                Label("Choose time", systemImage: "checkmark")
                            } else {
                                Text("Choose time")
                            }
                        }
                    } label: {
                        menuLabel(viewModel.useDepartureTime ? Text("Chosen time") : Text("Now"))
                    }
                    .accessibilityIdentifier("planner.departureMode")
                }
                if viewModel.useDepartureTime {
                    DatePicker("Leave at", selection: $viewModel.departureDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .environment(\.timeZone, TimeZone(identifier: "America/Sao_Paulo")!)
                        .padding(.leading, 40)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier("planner.departureDate")
                }
                Divider().padding(.leading, 40)
                settingRow(icon: "arrow.up.arrow.down.circle", title: "Sort by") {
                    Menu {
                        Picker("Sort by", selection: $viewModel.rankingPriority) {
                            Text("Arrive earliest").tag("arrives_first")
                            Text("Fewest transfers").tag("fewest_transfers")
                            Text("Least walking").tag("least_walking")
                        }
                    } label: {
                        menuLabel(Text(LocalizedStringKey(sortLabelKey)))
                    }
                }
                Divider().padding(.leading, 40)
                settingRow(icon: "arrow.triangle.swap", title: "Max transfers") {
                    Menu {
                        Picker("Max transfers", selection: $viewModel.maxTransfers) {
                            ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                        }
                    } label: {
                        menuLabel(Text("\(viewModel.maxTransfers)"))
                    }
                }
                Text("Times shown in São Paulo time.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }

    private var sortLabelKey: String {
        switch viewModel.rankingPriority {
        case "fewest_transfers": return "Fewest transfers"
        case "least_walking": return "Least walking"
        default: return "Arrive earliest"
        }
    }

    private func settingRow<Trailing: View>(icon: String, title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body.weight(.medium)).foregroundStyle(AppColors.primary).frame(width: 28)
            Text(title).font(.body)
            Spacer()
            trailing()
        }
        .padding(.vertical, 10)
    }

    private func menuLabel(_ text: Text) -> some View {
        HStack(spacing: 4) {
            text.font(.body.weight(.medium))
            Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(AppColors.primary)
    }

    // MARK: - Search

    private var searchButton: some View {
        VStack(spacing: 8) {
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
            if let left = viewModel.searchesLeft {
                Text(String(format: NSLocalizedString("Free searches today: %lld of %lld left", comment: ""), left, PlannerLimits.freeDailySearches))
                    .font(.caption)
                    .foregroundStyle(left == 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .accessibilityIdentifier("planner.searchesLeft")
            }
        }
    }

    @ViewBuilder private var results: some View {
        if viewModel.hasPlanned, let context = viewModel.resultContext {
            VStack(alignment: .leading, spacing: 14) {
                ImageBanner(imageName: resultsImage(for: context.destinationLabel), height: 132) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Journey options").font(.title2.bold())
                        Text("\(context.originLabel) → \(context.destinationLabel)").font(.subheadline).lineLimit(2)
                        Text(context.departure, format: .dateTime.day().month().hour().minute())
                            .environment(\.timeZone, TimeZone(identifier: "America/Sao_Paulo")!)
                            .font(.caption).opacity(0.85)
                    }
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

    /// Alternates the two results illustrations, stable for a destination.
    private func resultsImage(for destination: String) -> String {
        destination.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 2 == 0 ? "planner_results_luz" : "planner_results_ipiranga"
    }

    private func search() {
        focusedField = nil
        directOnly = false
        Task {
            await viewModel.planTrip()
            await refreshConditionsIfNeeded()
        }
    }

    private func refreshConditionsIfNeeded() async {
        if viewModel.alternatives.contains(where: { $0.vehicleLegs.contains(where: { $0.railSource != nil }) }) {
            await conditions.refresh()
        }
    }
}

private struct PremiumSource: Identifiable {
    let id: String
}

private extension PlannerPremiumPrompt {
    var messageKey: String {
        switch self {
        case .saveLimit: return "planner.premium.save_limit"
        case .searchLimit: return "planner.premium.search_limit"
        case .chooseTime: return "planner.premium.choose_time"
        }
    }
}

/// Origin ring, line, destination pin: the same rail language as the stop timeline.
private struct PlaceRail: View {
    let isFirst: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(isFirst ? Color.clear : AppColors.primary.opacity(0.35)).frame(width: 3)
            if isFirst {
                Circle().strokeBorder(AppColors.primary, lineWidth: 4).frame(width: 18, height: 18)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.primary)
            }
            Rectangle().fill(isFirst ? AppColors.primary.opacity(0.35) : Color.clear).frame(width: 3)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Saved origin → destination pairs, searched now with one tap.
private struct SavedRoutesSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    let onUse: (SavedRoute) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.savedRoutes.isEmpty {
                        ContentUnavailableView("No saved routes", systemImage: "bookmark",
                            description: Text("Choose an origin and destination, then save them here to search with one tap."))
                    }
                    ForEach(viewModel.savedRoutes) { route in
                        JourneyCard {
                            HStack(spacing: 12) {
                                Button { onUse(route) } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(route.originIsCurrentLocation ? SearchViewModel.currentLocationLabel : route.origin.name)
                                                .font(.headline).lineLimit(1)
                                            Label(route.destination.name, systemImage: "arrow.down")
                                                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                            Text("Search now").font(.caption.weight(.semibold)).foregroundStyle(AppColors.primary)
                                        }
                                        Spacer(minLength: 8)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("planner.savedRoute")
                                Button(role: .destructive) { viewModel.deleteRoute(route) } label: {
                                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove route")
                            }
                        }
                    }

                    Button {
                        viewModel.saveCurrentRoute()
                    } label: {
                        Label(saveTitle, systemImage: "bookmark.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AppColors.primary.opacity(viewModel.canSaveCurrentRoute ? 0.14 : 0.06), in: Capsule())
                    }
                    .disabled(!viewModel.canSaveCurrentRoute)
                    .accessibilityIdentifier("planner.saveCurrentRoute")

                    if !viewModel.isPremium {
                        Text(String(format: NSLocalizedString("On the free plan you can save up to %lld routes.", comment: ""), PlannerLimits.freeSavedRoutes))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Saved routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.isPremium {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(viewModel.savedRoutes.count) / \(PlannerLimits.freeSavedRoutes)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var saveTitle: LocalizedStringKey {
        if viewModel.currentRouteIsSaved { return "Current route saved" }
        if viewModel.originLocation == nil || viewModel.destinationLocation == nil { return "Choose origin and destination to save" }
        return "Save current route"
    }
}

/// Header of the planner: São Paulo by night (MASP and Ponte Estaiada) with the screen's question.
private struct PlannerHeroHeader: View {
    var compact = false

    var body: some View {
        ImageBanner(imageName: "planner_header", height: compact ? 170 : 200) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where to?").font(.largeTitle.bold())
                Text("Bus, Metro and CPTM, door to door.").font(.subheadline.weight(.medium)).opacity(0.9)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// An illustration with a dark gradient and white text at the bottom, in the journey detail's card style.
struct ImageBanner<Content: View>: View {
    let imageName: String
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipped()
            .accessibilityHidden(true)
            .overlay(alignment: .bottomLeading) {
                content
                    .foregroundStyle(.white)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
