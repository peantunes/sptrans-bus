import Foundation
import Combine

@MainActor
final class PlacesManagerViewModel: ObservableObject {
    @Published var places: [UserPlace] = []
    @Published var currentLocation: Location?

    private let storageService: StorageServiceProtocol
    private let locationService: LocationServiceProtocol
    private let featureToggles: FeatureToggles.Type

    init(
        storageService: StorageServiceProtocol,
        locationService: LocationServiceProtocol,
        featureToggles: FeatureToggles.Type = FeatureToggles.self
    ) {
        self.storageService = storageService
        self.locationService = locationService
        self.featureToggles = featureToggles
    }

    func load() {
        locationService.requestLocationPermission()
        currentLocation = locationService.getCurrentLocation()
        places = storageService.getSavedPlaces()
            .filter { featureToggles.isUserPlaceTypeEnabled($0.type) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func savePlace(from draft: UserPlaceDraft) {
        guard featureToggles.isUserPlaceTypeEnabled(draft.type) else { return }

        let now = Date()
        let place = UserPlace(
            id: draft.placeId ?? UUID(),
            name: draft.name,
            location: draft.location,
            type: draft.type,
            customLabel: draft.customLabel,
            createdAt: draft.createdAt ?? now,
            updatedAt: now
        )
        storageService.savePlace(place)
        load()
    }

    func removePlace(_ place: UserPlace) {
        storageService.removePlace(id: place.id)
        load()
    }

    func getCurrentLocation() -> Location? {
        let location = locationService.getCurrentLocation()
        if let location {
            currentLocation = location
        }
        return location
    }

    var availablePlaceTypes: [UserPlaceType] {
        featureToggles.availableUserPlaceTypes
    }
}

struct UserPlaceDraft: Identifiable {
    let id: UUID
    var placeId: UUID?
    var name: String
    var type: UserPlaceType
    var customLabel: String?
    var location: Location
    var createdAt: Date?

    static func empty(defaultLocation: Location) -> UserPlaceDraft {
        UserPlaceDraft(
            id: UUID(),
            placeId: nil,
            name: "",
            type: .custom,
            customLabel: "",
            location: defaultLocation,
            createdAt: nil
        )
    }

    static func fromPlace(_ place: UserPlace) -> UserPlaceDraft {
        UserPlaceDraft(
            id: UUID(),
            placeId: place.id,
            name: place.name,
            type: place.type,
            customLabel: place.customLabel,
            location: place.location,
            createdAt: place.createdAt
        )
    }
}
