import SwiftUI
import MapKit

struct PlacesManagerView: View {
    @StateObject private var viewModel: PlacesManagerViewModel
    @State private var selectedFilter: PlacesFilter = .all
    @State private var draftForSheet: UserPlaceDraft?
    @State private var showDeleteAlert = false
    @State private var placePendingDelete: UserPlace?

    init(viewModel: PlacesManagerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                filterBar

                if filteredPlaces.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredPlaces) { place in
                        placeCard(place)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle(localized("places.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let defaultLocation = viewModel.currentLocation ?? .saoPaulo
                    draftForSheet = .empty(defaultLocation: defaultLocation)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear(perform: viewModel.load)
        .onAppear {
            if !availableFilters.contains(selectedFilter) {
                selectedFilter = .all
            }
        }
        .sheet(item: $draftForSheet) { draft in
            PlaceEditorSheet(
                title: draft.placeId == nil ? localized("places.add") : localized("places.edit"),
                initialDraft: draft,
                availablePlaceTypes: viewModel.availablePlaceTypes,
                onUseCurrentLocation: { viewModel.getCurrentLocation() },
                onSave: { updatedDraft in
                    viewModel.savePlace(from: updatedDraft)
                }
            )
        }
        .alert(localized("places.delete.title"), isPresented: $showDeleteAlert) {
            Button(localized("places.delete.confirm"), role: .destructive) {
                if let placePendingDelete {
                    viewModel.removePlace(placePendingDelete)
                }
                placePendingDelete = nil
            }
            Button(localized("common.cancel"), role: .cancel) {
                placePendingDelete = nil
            }
        } message: {
            Text(localized("places.delete.message"))
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.title)
                            .font(AppFonts.caption())
                            .foregroundColor(selectedFilter == filter ? .white : AppColors.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedFilter == filter ? AppColors.primary : AppColors.lightGray.opacity(0.35))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var availableFilters: [PlacesFilter] {
        PlacesFilter.availableCases(homeWorkEnabled: FeatureToggles.isHomeWorkLocationsEnabled)
    }

    private var filteredPlaces: [UserPlace] {
        viewModel.places.filter { selectedFilter.matches($0) }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("places.empty.title"))
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)

                Text(emptyStateMessage)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.65))

                Button(localized("places.add")) {
                    let defaultLocation = viewModel.currentLocation ?? .saoPaulo
                    draftForSheet = .empty(defaultLocation: defaultLocation)
                }
                .font(AppFonts.callout())
                .foregroundColor(AppColors.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyStateMessage: String {
        if FeatureToggles.isHomeWorkLocationsEnabled {
            return localized("places.empty.message.full")
        }
        return localized("places.empty.message.limited")
    }

    private func placeCard(_ place: UserPlace) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(placeTypeTitle(for: place), systemImage: placeTypeIcon(for: place))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.primary)

                    Spacer()

                    Button {
                        draftForSheet = .fromPlace(place)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(AppColors.secondary)
                    }

                    Button {
                        placePendingDelete = place
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.statusWarning)
                    }
                }

                Text(place.name)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Text(String(format: localized("places.coordinates_format"), place.location.latitude, place.location.longitude))
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func placeTypeTitle(for place: UserPlace) -> String {
        if place.type == .custom, let customLabel = place.customLabel, !customLabel.isEmpty {
            return customLabel
        }
        return placeTypeTitle(for: place.type)
    }

    private func placeTypeIcon(for place: UserPlace) -> String {
        switch place.type {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .custom: return "mappin.circle.fill"
        }
    }

    private func placeTypeTitle(for type: UserPlaceType) -> String {
        switch type {
        case .home: return localized("places.type.home")
        case .work: return localized("places.type.work")
        case .study: return localized("places.type.study")
        case .custom: return localized("places.type.custom")
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private enum PlacesFilter: String, Identifiable {
    case all
    case home
    case work
    case study
    case custom

    var id: String { rawValue }

    static func availableCases(homeWorkEnabled: Bool) -> [PlacesFilter] {
        if homeWorkEnabled {
            return [.all, .home, .work, .study, .custom]
        }
        return [.all, .study, .custom]
    }

    var title: String {
        switch self {
        case .all: return NSLocalizedString("places.filter.all", comment: "")
        case .home: return NSLocalizedString("places.filter.home", comment: "")
        case .work: return NSLocalizedString("places.filter.work", comment: "")
        case .study: return NSLocalizedString("places.filter.study", comment: "")
        case .custom: return NSLocalizedString("places.filter.custom", comment: "")
        }
    }

    func matches(_ place: UserPlace) -> Bool {
        switch self {
        case .all: return true
        case .home: return place.type == .home
        case .work: return place.type == .work
        case .study: return place.type == .study
        case .custom: return place.type == .custom
        }
    }
}

private struct PlaceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialDraft: UserPlaceDraft
    let availablePlaceTypes: [UserPlaceType]
    let onUseCurrentLocation: () -> Location?
    let onSave: (UserPlaceDraft) -> Void

    @State private var name: String
    @State private var selectedType: UserPlaceType
    @State private var customLabel: String
    @State private var searchQuery: String
    @State private var isSearching: Bool
    @State private var searchResults: [PlaceSearchResult]
    @State private var pendingLocation: Location?
    @State private var pendingTitle: String?
    @State private var confirmedLocation: Location
    @State private var locationConfirmed: Bool
    @State private var previewRegion: MKCoordinateRegion
    @State private var locationMessage: String?

    init(
        title: String,
        initialDraft: UserPlaceDraft,
        availablePlaceTypes: [UserPlaceType],
        onUseCurrentLocation: @escaping () -> Location?,
        onSave: @escaping (UserPlaceDraft) -> Void
    ) {
        self.title = title
        self.initialDraft = initialDraft
        self.availablePlaceTypes = availablePlaceTypes
        self.onUseCurrentLocation = onUseCurrentLocation
        self.onSave = onSave
        let initialType = availablePlaceTypes.contains(initialDraft.type) ? initialDraft.type : .custom
        _name = State(initialValue: initialDraft.name)
        _selectedType = State(initialValue: initialType)
        _customLabel = State(initialValue: initialDraft.customLabel ?? "")
        _searchQuery = State(initialValue: "")
        _isSearching = State(initialValue: false)
        _searchResults = State(initialValue: [])
        _pendingLocation = State(initialValue: nil)
        _pendingTitle = State(initialValue: nil)
        _confirmedLocation = State(initialValue: initialDraft.location)
        _locationConfirmed = State(initialValue: true)
        _previewRegion = State(initialValue: MKCoordinateRegion(
            center: initialDraft.location.toCLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        _locationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("places.editor.details.section")) {
                    TextField(localized("places.editor.name.placeholder"), text: $name)
                    Picker(localized("places.editor.type.title"), selection: $selectedType) {
                        ForEach(availablePlaceTypes, id: \.rawValue) { type in
                            Text(placeTypeTitle(for: type)).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    if selectedType == .custom {
                        TextField(localized("places.editor.custom_label.placeholder"), text: $customLabel)
                    }
                }

                Section(localized("places.editor.search.section")) {
                    HStack(spacing: 8) {
                        TextField(localized("places.editor.search.placeholder"), text: $searchQuery)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onSubmit {
                                Task { await runSearch() }
                            }

                        Button {
                            Task { await runSearch() }
                        } label: {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .disabled(isSearching || searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let locationMessage, !locationMessage.isEmpty {
                        Text(locationMessage)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.statusWarning)
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(AppFonts.subheadline())
                                        .foregroundColor(AppColors.text)

                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.text.opacity(0.6))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(localized("places.editor.use_current_location")) {
                        guard let currentLocation = onUseCurrentLocation() else {
                            locationMessage = localized("places.editor.current_location_unavailable")
                            return
                        }
                        pendingLocation = currentLocation
                        pendingTitle = localized("places.editor.current_location_title")
                        locationConfirmed = false
                        previewRegion.center = currentLocation.toCLLocationCoordinate2D()
                        previewRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        locationMessage = localized("places.editor.location_selected")
                    }
                }

                Section(localized("places.editor.map_confirmation.section")) {
                    Map(
                        coordinateRegion: $previewRegion,
                        interactionModes: [.zoom, .pan],
                        annotationItems: previewPins
                    ) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.primary)
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                    }
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let pendingLocation {
                        Button {
                            confirmPendingLocation()
                        } label: {
                            Text(localized("places.editor.confirm_location"))
                                .font(AppFonts.callout())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Text(String(format: localized("places.editor.pending_coordinates_format"), pendingLocation.latitude, pendingLocation.longitude))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.65))
                    } else {
                        Text(String(format: localized("places.editor.confirmed_coordinates_format"), confirmedLocation.latitude, confirmedLocation.longitude))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.statusNormal)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localized("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("common.save")) {
                        onSave(
                            UserPlaceDraft(
                                id: initialDraft.id,
                                placeId: initialDraft.placeId,
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                type: selectedType,
                                customLabel: selectedType == .custom ? customLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                location: confirmedLocation,
                                createdAt: initialDraft.createdAt
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              locationConfirmed,
              availablePlaceTypes.contains(selectedType),
              (-90...90).contains(confirmedLocation.latitude),
              (-180...180).contains(confirmedLocation.longitude) else {
            return false
        }

        if selectedType == .custom {
            return !customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return true
    }

    private func placeTypeTitle(for type: UserPlaceType) -> String {
        switch type {
        case .home: return localized("places.type.home")
        case .work: return localized("places.type.work")
        case .study: return localized("places.type.study")
        case .custom: return localized("places.type.custom")
        }
    }

    private var previewPins: [MapConfirmationPin] {
        if let pendingLocation {
            return [MapConfirmationPin(location: pendingLocation)]
        }
        return [MapConfirmationPin(location: confirmedLocation)]
    }

    @MainActor
    private func runSearch() async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        locationMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.region = .saoPauloMetro

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems
                .filter { MKCoordinateRegion.saoPauloMetro.contains($0.placemark.coordinate) }
                .prefix(8)
                .map(PlaceSearchResult.init)

            if searchResults.isEmpty {
                locationMessage = localized("places.editor.search.no_results")
            }
        } catch {
            locationMessage = error.localizedDescription
            searchResults = []
        }

        isSearching = false
    }

    private func selectSearchResult(_ result: PlaceSearchResult) {
        pendingLocation = result.location
        pendingTitle = result.title
        searchQuery = result.title
        locationConfirmed = false
        previewRegion.center = result.location.toCLLocationCoordinate2D()
        previewRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        locationMessage = localized("places.editor.location_selected")
    }

    private func confirmPendingLocation() {
        guard let pendingLocation else { return }

        confirmedLocation = pendingLocation
        self.pendingLocation = nil
        searchResults = []
        locationConfirmed = true
        locationMessage = nil

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let pendingTitle, !pendingTitle.isEmpty {
            name = pendingTitle
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PlaceSearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let location: Location

    init(mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        let name = mapItem.name ?? mapItem.placemark.title ?? NSLocalizedString("places.editor.selected_place", comment: "")
        let subtitleValue = mapItem.placemark.title ?? ""

        title = name
        subtitle = subtitleValue == name ? "" : subtitleValue
        location = Location(latitude: coordinate.latitude, longitude: coordinate.longitude)
        id = "\(name)-\(coordinate.latitude)-\(coordinate.longitude)"
    }
}

private struct MapConfirmationPin: Identifiable {
    let id = UUID()
    let location: Location

    var coordinate: CLLocationCoordinate2D {
        location.toCLLocationCoordinate2D()
    }
}

#Preview {
    NavigationStack {
        PlacesManagerView(
            viewModel: PlacesManagerViewModel(
                storageService: SwiftDataStorageService(modelContainer: LocalDataModelContainer.shared),
                locationService: CoreLocationService()
            )
        )
    }
}
