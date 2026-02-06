import Foundation
import SwiftData

@Model
final class UserPlaceModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var typeRawValue: String
    var customLabel: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        typeRawValue: String,
        customLabel: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.typeRawValue = typeRawValue
        self.customLabel = customLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
