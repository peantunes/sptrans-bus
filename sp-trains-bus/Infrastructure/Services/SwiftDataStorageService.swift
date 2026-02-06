import Foundation
import SwiftData

class SwiftDataStorageService: StorageServiceProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func saveFavorite(stop: Stop) {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<FavoriteStopModel>(
                predicate: #Predicate { model in
                    model.stopId == stop.stopId
                }
            )

            if let existing = try context.fetch(descriptor).first {
                existing.stopName = stop.stopName
                existing.latitude = stop.location.latitude
                existing.longitude = stop.location.longitude
                existing.stopSequence = stop.stopSequence
                existing.stopCode = stop.stopCode
                existing.wheelchairBoarding = stop.wheelchairBoarding
            } else {
                let model = FavoriteStopModel(
                    stopId: stop.stopId,
                    stopName: stop.stopName,
                    latitude: stop.location.latitude,
                    longitude: stop.location.longitude,
                    stopSequence: stop.stopSequence,
                    stopCode: stop.stopCode,
                    wheelchairBoarding: stop.wheelchairBoarding
                )
                context.insert(model)
            }

            try context.save()
        } catch {
            print("saveFavorite failed: \(error.localizedDescription)")
        }
    }

    func removeFavorite(stop: Stop) {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<FavoriteStopModel>(
                predicate: #Predicate { model in
                    model.stopId == stop.stopId
                }
            )

            let models = try context.fetch(descriptor)
            models.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("removeFavorite failed: \(error.localizedDescription)")
        }
    }

    func isFavorite(stopId: Int) -> Bool {
        let context = ModelContext(modelContainer)

        do {
            var descriptor = FetchDescriptor<FavoriteStopModel>(
                predicate: #Predicate { model in
                    model.stopId == stopId
                }
            )
            descriptor.fetchLimit = 1
            return try !context.fetch(descriptor).isEmpty
        } catch {
            print("isFavorite failed: \(error.localizedDescription)")
            return false
        }
    }

    func getFavoriteStops() -> [Stop] {
        let context = ModelContext(modelContainer)

        do {
            var descriptor = FetchDescriptor<FavoriteStopModel>()
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]

            let models = try context.fetch(descriptor)
            return models.map { model in
                Stop(
                    stopId: model.stopId,
                    stopName: model.stopName,
                    location: Location(latitude: model.latitude, longitude: model.longitude),
                    stopSequence: model.stopSequence,
                    stopCode: model.stopCode,
                    wheelchairBoarding: model.wheelchairBoarding
                )
            }
        } catch {
            print("getFavoriteStops failed: \(error.localizedDescription)")
            return []
        }
    }

    func savePlace(_ place: UserPlace) {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<UserPlaceModel>(
                predicate: #Predicate { model in
                    model.id == place.id
                }
            )

            if let existing = try context.fetch(descriptor).first {
                existing.name = place.name
                existing.latitude = place.location.latitude
                existing.longitude = place.location.longitude
                existing.typeRawValue = place.type.rawValue
                existing.customLabel = place.customLabel
                existing.updatedAt = place.updatedAt
            } else {
                let model = UserPlaceModel(
                    id: place.id,
                    name: place.name,
                    latitude: place.location.latitude,
                    longitude: place.location.longitude,
                    typeRawValue: place.type.rawValue,
                    customLabel: place.customLabel,
                    createdAt: place.createdAt,
                    updatedAt: place.updatedAt
                )
                context.insert(model)
            }

            try context.save()
        } catch {
            print("savePlace failed: \(error.localizedDescription)")
        }
    }

    func removePlace(id: UUID) {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<UserPlaceModel>(
                predicate: #Predicate { model in
                    model.id == id
                }
            )

            let models = try context.fetch(descriptor)
            models.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("removePlace failed: \(error.localizedDescription)")
        }
    }

    func getSavedPlaces() -> [UserPlace] {
        let context = ModelContext(modelContainer)

        do {
            var descriptor = FetchDescriptor<UserPlaceModel>()
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]

            return try context.fetch(descriptor).compactMap { model in
                guard let type = UserPlaceType(rawValue: model.typeRawValue) else {
                    return nil
                }

                return UserPlace(
                    id: model.id,
                    name: model.name,
                    location: Location(latitude: model.latitude, longitude: model.longitude),
                    type: type,
                    customLabel: model.customLabel,
                    createdAt: model.createdAt,
                    updatedAt: model.updatedAt
                )
            }
        } catch {
            print("getSavedPlaces failed: \(error.localizedDescription)")
            return []
        }
    }

    func getPlaces(type: UserPlaceType) -> [UserPlace] {
        return getSavedPlaces().filter { $0.type == type }
    }

    func saveHome(location: Location) {
        let now = Date()
        getPlaces(type: .home).forEach { removePlace(id: $0.id) }
        savePlace(
            UserPlace(
                name: "Home",
                location: location,
                type: .home,
                createdAt: now,
                updatedAt: now
            )
        )
    }

    func getHomeLocation() -> Location? {
        return getPlaces(type: .home).first?.location
    }

    func saveWork(location: Location) {
        let now = Date()
        getPlaces(type: .work).forEach { removePlace(id: $0.id) }
        savePlace(
            UserPlace(
                name: "Work",
                location: location,
                type: .work,
                createdAt: now,
                updatedAt: now
            )
        )
    }

    func getWorkLocation() -> Location? {
        return getPlaces(type: .work).first?.location
    }
}
