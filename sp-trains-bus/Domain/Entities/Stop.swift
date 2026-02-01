import Foundation

struct Stop: Codable {
    let stopId: Int
    let stopName: String
    let location: Location
    let stopSequence: Int
    let stopCode: String
    let wheelchairBoarding: Int
}
