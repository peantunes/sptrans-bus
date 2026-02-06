import Foundation
import SwiftData

@Model
final class GTFSRouteModel {
    @Attribute(.unique) var routeId: String
    var agencyId: Int
    var routeShortName: String
    var routeLongName: String
    var routeDesc: String
    var routeType: Int
    var routeColor: String
    var routeTextColor: String

    init(
        routeId: String,
        agencyId: Int,
        routeShortName: String,
        routeLongName: String,
        routeDesc: String,
        routeType: Int,
        routeColor: String,
        routeTextColor: String
    ) {
        self.routeId = routeId
        self.agencyId = agencyId
        self.routeShortName = routeShortName
        self.routeLongName = routeLongName
        self.routeDesc = routeDesc
        self.routeType = routeType
        self.routeColor = routeColor
        self.routeTextColor = routeTextColor
    }
}
