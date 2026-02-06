import Foundation
import SwiftData

@Model
final class GTFSCalendarModel {
    @Attribute(.unique) var serviceId: String
    var monday: Bool
    var tuesday: Bool
    var wednesday: Bool
    var thursday: Bool
    var friday: Bool
    var saturday: Bool
    var sunday: Bool
    var startDate: String
    var endDate: String

    init(
        serviceId: String,
        monday: Bool,
        tuesday: Bool,
        wednesday: Bool,
        thursday: Bool,
        friday: Bool,
        saturday: Bool,
        sunday: Bool,
        startDate: String,
        endDate: String
    ) {
        self.serviceId = serviceId
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.sunday = sunday
        self.startDate = startDate
        self.endDate = endDate
    }
}
