import Foundation
import SwiftData

enum LocalDataModelContainer {
    static let shared: ModelContainer = make()

    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            return try ModelContainer(
                for: FavoriteStopModel.self,
                UserPlaceModel.self,
                GTFSFeedMetadataModel.self,
                GTFSStopModel.self,
                GTFSRouteModel.self,
                GTFSTripModel.self,
                GTFSStopTimeModel.self,
                GTFSShapePointModel.self,
                GTFSCalendarModel.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize local model container: \(error.localizedDescription)")
        }
    }
}
