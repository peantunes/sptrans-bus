import Foundation

enum UserPlaceType: String, Codable, CaseIterable {
    case home
    case work
    case study
    case custom
}

struct UserPlace: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let location: Location
    let type: UserPlaceType
    let customLabel: String?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        location: Location,
        type: UserPlaceType,
        customLabel: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.type = type
        self.customLabel = customLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
