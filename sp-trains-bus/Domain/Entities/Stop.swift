import Foundation

struct Stop: Codable, Identifiable {
    var id: String {
        stopId
    }
    let stopId: String
    let stopName: String
    let location: Location
    let stopSequence: Int
    let stopCode: String
    let wheelchairBoarding: Int
}
