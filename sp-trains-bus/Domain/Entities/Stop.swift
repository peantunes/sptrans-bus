import Foundation

struct Stop: Codable, Identifiable {
    var id: Int {
        stopId
    }
    let stopId: Int
    let stopName: String
    let location: Location
    let stopSequence: Int
    let stopCode: String
    let wheelchairBoarding: Int
}
