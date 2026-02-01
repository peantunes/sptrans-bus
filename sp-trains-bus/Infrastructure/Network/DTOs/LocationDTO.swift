import Foundation

struct LocationDTO: Decodable {
    let lat: Double
    let lon: Double
    let sequence: Int?
    let distTraveled: Double?

    func toDomain() -> Location {
        return Location(latitude: lat, longitude: lon)
    }
}

struct ShapeResponse: Decodable {
    let shapeId: String
    let count: Int
    let points: [LocationDTO]
}