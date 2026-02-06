import Foundation
import SwiftData

enum GTFSImportError: LocalizedError {
    case inputIsNotDirectory
    case missingRequiredFile(String)

    var errorDescription: String? {
        switch self {
        case .inputIsNotDirectory:
            return "GTFS import expects an extracted directory with .txt files."
        case .missingRequiredFile(let fileName):
            return "Missing required GTFS file: \(fileName)"
        }
    }
}

final class GTFSImporterService: GTFSImportServiceProtocol {
    private let modelContainer: ModelContainer
    private let feedService: GTFSFeedServiceProtocol
    private let fileManager: FileManager
    private let batchSize: Int

    init(
        modelContainer: ModelContainer,
        feedService: GTFSFeedServiceProtocol,
        fileManager: FileManager = .default,
        batchSize: Int = 2_000
    ) {
        self.modelContainer = modelContainer
        self.feedService = feedService
        self.fileManager = fileManager
        self.batchSize = batchSize
    }

    func hasImportedData() -> Bool {
        let context = ModelContext(modelContainer)
        do {
            var descriptor = FetchDescriptor<GTFSStopModel>()
            descriptor.fetchLimit = 1
            return try !context.fetch(descriptor).isEmpty
        } catch {
            return false
        }
    }

    func importFromDirectory(_ directoryURL: URL, sourceURL: String?) async throws -> GTFSFeedInfo {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw GTFSImportError.inputIsNotDirectory
        }

        let stopsURL = try requiredFileURL(in: directoryURL, fileName: "stops.txt")
        let routesURL = try requiredFileURL(in: directoryURL, fileName: "routes.txt")
        let tripsURL = try requiredFileURL(in: directoryURL, fileName: "trips.txt")
        let stopTimesURL = try requiredFileURL(in: directoryURL, fileName: "stop_times.txt")
        let shapesURL = optionalFileURL(in: directoryURL, fileName: "shapes.txt")
        let calendarURL = optionalFileURL(in: directoryURL, fileName: "calendar.txt")
        let feedInfoURL = optionalFileURL(in: directoryURL, fileName: "feed_info.txt")

        let context = ModelContext(modelContainer)
        try clearExistingGTFSData(in: context)
        try importStops(from: stopsURL, context: context)
        try importRoutes(from: routesURL, context: context)
        try importTrips(from: tripsURL, context: context)
        try importStopTimes(from: stopTimesURL, context: context)
        if let shapesURL {
            try importShapes(from: shapesURL, context: context)
        }
        if let calendarURL {
            try importCalendar(from: calendarURL, context: context)
        }
        try context.save()

        let versionIdentifier = (try feedVersion(from: feedInfoURL)) ?? fallbackVersionIdentifier()
        let importedAt = Date()
        let persistedArchivePath = resolvedArchivePath(sourceURL: sourceURL, fallbackDirectoryURL: directoryURL)
        let feed = GTFSFeedInfo(
            versionIdentifier: versionIdentifier,
            sourceURL: sourceURL,
            localArchivePath: persistedArchivePath,
            downloadedAt: importedAt,
            lastCheckedAt: importedAt,
            etag: nil,
            lastModified: nil
        )
        feedService.updateFeed(feed)

        return feed
    }

    private func resolvedArchivePath(sourceURL: String?, fallbackDirectoryURL: URL) -> String {
        guard let sourceURL,
              let parsedURL = URL(string: sourceURL),
              parsedURL.isFileURL else {
            return fallbackDirectoryURL.path
        }

        return parsedURL.path
    }

    private func clearExistingGTFSData(in context: ModelContext) throws {
        try deleteAll(in: context, model: GTFSStopTimeModel.self)
        try deleteAll(in: context, model: GTFSShapePointModel.self)
        try deleteAll(in: context, model: GTFSTripModel.self)
        try deleteAll(in: context, model: GTFSRouteModel.self)
        try deleteAll(in: context, model: GTFSStopModel.self)
        try deleteAll(in: context, model: GTFSCalendarModel.self)
        try context.save()
    }

    private func importStops(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let stopId = intValue(row["stop_id"]),
                  let stopName = row["stop_name"],
                  let stopLat = doubleValue(row["stop_lat"]),
                  let stopLon = doubleValue(row["stop_lon"]) else {
                return
            }

            context.insert(
                GTFSStopModel(
                    stopId: stopId,
                    stopCode: row["stop_code"] ?? "",
                    stopName: stopName,
                    stopLat: stopLat,
                    stopLon: stopLon,
                    wheelchairBoarding: intValue(row["wheelchair_boarding"]) ?? 0
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func importRoutes(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let routeId = row["route_id"], !routeId.isEmpty else {
                return
            }

            context.insert(
                GTFSRouteModel(
                    routeId: routeId,
                    agencyId: intValue(row["agency_id"]) ?? 0,
                    routeShortName: row["route_short_name"] ?? "",
                    routeLongName: row["route_long_name"] ?? "",
                    routeDesc: row["route_desc"] ?? "",
                    routeType: intValue(row["route_type"]) ?? 3,
                    routeColor: row["route_color"] ?? "000000",
                    routeTextColor: row["route_text_color"] ?? "FFFFFF"
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func importTrips(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let tripId = row["trip_id"], !tripId.isEmpty,
                  let routeId = row["route_id"], !routeId.isEmpty,
                  let serviceId = row["service_id"], !serviceId.isEmpty else {
                return
            }

            context.insert(
                GTFSTripModel(
                    tripId: tripId,
                    routeId: routeId,
                    serviceId: serviceId,
                    tripHeadsign: row["trip_headsign"] ?? "",
                    directionId: intValue(row["direction_id"]) ?? 0,
                    shapeId: row["shape_id"] ?? ""
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func importStopTimes(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let tripId = row["trip_id"], !tripId.isEmpty,
                  let arrivalTime = row["arrival_time"], !arrivalTime.isEmpty,
                  let departureTime = row["departure_time"], !departureTime.isEmpty,
                  let stopId = intValue(row["stop_id"]),
                  let stopSequence = intValue(row["stop_sequence"]) else {
                return
            }

            context.insert(
                GTFSStopTimeModel(
                    tripId: tripId,
                    arrivalTime: arrivalTime,
                    departureTime: departureTime,
                    stopId: stopId,
                    stopSequence: stopSequence
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func importShapes(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let shapeId = row["shape_id"], !shapeId.isEmpty,
                  let shapePtLat = doubleValue(row["shape_pt_lat"]),
                  let shapePtLon = doubleValue(row["shape_pt_lon"]),
                  let shapePtSequence = intValue(row["shape_pt_sequence"]) else {
                return
            }

            context.insert(
                GTFSShapePointModel(
                    shapeId: shapeId,
                    shapePtLat: shapePtLat,
                    shapePtLon: shapePtLon,
                    shapePtSequence: shapePtSequence
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func importCalendar(from url: URL, context: ModelContext) throws {
        var count = 0
        try processCSVFile(at: url) { [weak self] row in
            guard let self else { return }
            guard let serviceId = row["service_id"], !serviceId.isEmpty else {
                return
            }

            context.insert(
                GTFSCalendarModel(
                    serviceId: serviceId,
                    monday: intValue(row["monday"]) == 1,
                    tuesday: intValue(row["tuesday"]) == 1,
                    wednesday: intValue(row["wednesday"]) == 1,
                    thursday: intValue(row["thursday"]) == 1,
                    friday: intValue(row["friday"]) == 1,
                    saturday: intValue(row["saturday"]) == 1,
                    sunday: intValue(row["sunday"]) == 1,
                    startDate: row["start_date"] ?? "19000101",
                    endDate: row["end_date"] ?? "29991231"
                )
            )
            count += 1

            if count % batchSize == 0 {
                try context.save()
            }
        }
    }

    private func processCSVFile(at fileURL: URL, rowHandler: @escaping ([String: String]) throws -> Void) throws {
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        let parser = CSVLineParser()

        var headers: [String] = []
        var thrownError: Error?

        fileContents.enumerateLines { line, stop in
            if thrownError != nil {
                stop = true
                return
            }

            let normalizedLine = line.replacingOccurrences(of: "\r", with: "")
            if normalizedLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }

            let columns = parser.parse(line: normalizedLine)
            if headers.isEmpty {
                headers = columns
                return
            }

            var values = columns
            if values.count < headers.count {
                values.append(contentsOf: Array(repeating: "", count: headers.count - values.count))
            }

            let row = Dictionary(uniqueKeysWithValues: zip(headers, values))

            do {
                try rowHandler(row)
            } catch {
                thrownError = error
                stop = true
            }
        }

        if let thrownError {
            throw thrownError
        }
    }

    private func requiredFileURL(in directoryURL: URL, fileName: String) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw GTFSImportError.missingRequiredFile(fileName)
        }
        return fileURL
    }

    private func optionalFileURL(in directoryURL: URL, fileName: String) -> URL? {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func deleteAll<Model: PersistentModel>(in context: ModelContext, model: Model.Type) throws {
        let models = try context.fetch(FetchDescriptor<Model>())
        for value in models {
            context.delete(value)
        }
    }

    private func feedVersion(from feedInfoURL: URL?) throws -> String? {
        guard let feedInfoURL else { return nil }

        var version: String?
        try processCSVFile(at: feedInfoURL) { row in
            let candidate = row["feed_version"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let candidate, !candidate.isEmpty {
                version = candidate
            }
        }
        return version
    }

    private func fallbackVersionIdentifier() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func intValue(_ raw: String?) -> Int? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return Int(value)
    }

    private func doubleValue(_ raw: String?) -> Double? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return Double(value)
    }
}

private struct CSVLineParser {
    func parse(line: String) -> [String] {
        var results: [String] = []
        var current = ""
        var insideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if character == "\"" {
                let nextIndex = line.index(after: index)
                if insideQuotes && nextIndex < line.endIndex && line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    insideQuotes.toggle()
                }
            } else if character == "," && !insideQuotes {
                results.append(current)
                current = ""
            } else {
                current.append(character)
            }

            index = line.index(after: index)
        }

        results.append(current)
        return results
    }
}
