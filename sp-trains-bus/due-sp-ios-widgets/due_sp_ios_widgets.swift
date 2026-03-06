import WidgetKit
import SwiftUI
import AppIntents
import CoreLocation

struct RailStatusEntryProvider: AppIntentTimelineProvider {
    typealias Intent = RailStatusWidgetIntent
    typealias Entry = IOSWidgetEntry

    private let store = WidgetSnapshotStore()
    private let apiService = SharedTransitAPIService()

    func placeholder(in context: Context) -> IOSWidgetEntry {
        IOSWidgetEntry(date: Date(), snapshot: .empty, preferredStopID: nil, selectedRailLineKeys: [])
    }

    func snapshot(for configuration: RailStatusWidgetIntent, in context: Context) async -> IOSWidgetEntry {
        await loadEntry(selectedRailLineKeys: configuration.selectedLineKeys)
    }

    func timeline(for configuration: RailStatusWidgetIntent, in context: Context) async -> Timeline<IOSWidgetEntry> {
        let entry = await loadEntry(selectedRailLineKeys: configuration.selectedLineKeys)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func loadEntry(selectedRailLineKeys: [String]) async -> IOSWidgetEntry {
        let preferredStopID = store.loadPreferredStopID()
        let favoriteLineIDs = store.loadFavoriteLineIDs()
        let snapshot = WidgetTransitSnapshot(
            sharedSnapshot: await apiService.fetchSnapshot(
                preferredStopID: preferredStopID,
                favoriteLineIDs: favoriteLineIDs
            )
        )
        return IOSWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            preferredStopID: preferredStopID,
            selectedRailLineKeys: selectedRailLineKeys
        )
    }
}

struct NextArrivalEntryProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()
    private let apiService = SharedTransitAPIService()

    func placeholder(in context: Context) -> IOSWidgetEntry {
        IOSWidgetEntry(date: Date(), snapshot: .empty, preferredStopID: nil, selectedRailLineKeys: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (IOSWidgetEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IOSWidgetEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date().addingTimeInterval(600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func loadEntry() async -> IOSWidgetEntry {
        let preferredStopID = store.loadPreferredStopID()
        let favoriteLineIDs = store.loadFavoriteLineIDs()
        let snapshot = WidgetTransitSnapshot(
            sharedSnapshot: await apiService.fetchSnapshot(
                preferredStopID: preferredStopID,
                favoriteLineIDs: favoriteLineIDs
            )
        )
        return IOSWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            preferredStopID: preferredStopID,
            selectedRailLineKeys: []
        )
    }
}

struct NearbyStopsEntryProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()
    private let apiService = SharedTransitAPIService()

    func placeholder(in context: Context) -> IOSWidgetEntry {
        IOSWidgetEntry(date: Date(), snapshot: .empty, preferredStopID: nil, selectedRailLineKeys: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (IOSWidgetEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IOSWidgetEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date().addingTimeInterval(600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func loadEntry() async -> IOSWidgetEntry {
        let preferredStopID = store.loadPreferredStopID()
        let favoriteLineIDs = store.loadFavoriteLineIDs()
        let coordinate = await WidgetLocationResolver.currentCoordinate()
        let snapshot = WidgetTransitSnapshot(
            sharedSnapshot: await apiService.fetchSnapshot(
                preferredStopID: preferredStopID,
                favoriteLineIDs: favoriteLineIDs,
                nearbyLatitude: coordinate?.latitude,
                nearbyLongitude: coordinate?.longitude
            )
        )
        return IOSWidgetEntry(
            date: Date(),
            snapshot: snapshot,
            preferredStopID: preferredStopID,
            selectedRailLineKeys: []
        )
    }
}

struct IOSWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTransitSnapshot
    let preferredStopID: Int?
    let selectedRailLineKeys: [String]
}

struct due_sp_ios_status: Widget {
    let kind: String = "due_sp_ios_status"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RailStatusWidgetIntent.self, provider: RailStatusEntryProvider()) { entry in
            IOSRailStatusWidgetView(entry: entry)
                .widgetLiquidGlassBackground()
        }
        .configurationDisplayName("Due SP Status")
        .description("Current rail line status.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct due_sp_ios_next_arrival: Widget {
    let kind: String = "due_sp_ios_next_arrival"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextArrivalEntryProvider()) { entry in
            IOSNextArrivalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Due SP Next Arrival")
        .description("Next ETA for your preferred stop.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct due_sp_ios_nearby_stops: Widget {
    let kind: String = "due_sp_ios_nearby_stops"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearbyStopsEntryProvider()) { entry in
            IOSNearbyStopsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Due SP Nearby")
        .description("Closest stops and ETAs.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

private struct IOSRailStatusWidgetView: View {
    let entry: IOSWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var line: WidgetRailLineSnapshot? {
        displayedLines.first
    }

    private var topLines: [WidgetRailLineSnapshot] {
        Array(displayedLines.prefix(5))
    }

    private var displayedLines: [WidgetRailLineSnapshot] {
        guard !entry.selectedRailLineKeys.isEmpty else {
            return sortedRailLines
        }

        var selected: [WidgetRailLineSnapshot] = []
        var consumedIDs = Set<String>()

        for key in entry.selectedRailLineKeys {
            guard let match = entry.snapshot.railLines.first(where: {
                lineSelectionKey(for: $0) == key && !consumedIDs.contains($0.id)
            }) else {
                continue
            }
            selected.append(match)
            consumedIDs.insert(match.id)
        }

        return selected.isEmpty ? sortedRailLines : selected
    }

    private var sortedRailLines: [WidgetRailLineSnapshot] {
        entry.snapshot.railLines.sorted(by: sortLines)
    }

    private var updatedAtLabel: String {
        guard entry.snapshot.generatedAt > Date.distantPast else {
            return "Update unavailable"
        }
        return "Updated \(Self.widgetTimeFormatter.string(from: entry.snapshot.generatedAt))"
    }

    private static let widgetTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private func lineSelectionKey(for line: WidgetRailLineSnapshot) -> String {
        "\(line.source.lowercased())-\(line.lineNumber)"
    }

    private func sortLines(_ lhs: WidgetRailLineSnapshot, _ rhs: WidgetRailLineSnapshot) -> Bool {
        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite && !rhs.isFavorite
        }

        if lhs.severityRawValue != rhs.severityRawValue {
            return lhs.severityRawValue > rhs.severityRawValue
        }

        if lhs.source != rhs.source {
            return sourceRank(lhs.source) < sourceRank(rhs.source)
        }

        let lhsNumber = Int(lhs.lineNumber) ?? Int.max
        let rhsNumber = Int(rhs.lineNumber) ?? Int.max
        if lhsNumber == rhsNumber {
            return lhs.lineName < rhs.lineName
        }
        return lhsNumber < rhsNumber
    }

    private func sourceRank(_ source: String) -> Int {
        switch source.lowercased() {
        case "metro": return 0
        case "cptm": return 1
        default: return 2
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let line {
                    Text("L\(line.lineNumber) \(line.status)")
                } else {
                    Text("No status")
                }
            case .accessoryCircular:
                ZStack {
                    Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    Text(line.map { "L\($0.lineNumber)" } ?? "--")
                        .font(.caption2.bold())
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.map { "L\($0.lineNumber) \($0.lineName)" } ?? "No status")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Text(line?.status ?? "")
                        .font(.caption2)
                        .foregroundStyle(line.map { colorFromHex($0.statusColorHex) } ?? .secondary)
                        .lineLimit(1)
                }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Rail Status")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 4)

                        if let line {
                            Text("L\(line.lineNumber)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorFromHex(line.lineColorHex).opacity(0.22))
                                .clipShape(Capsule())
                        }
                    }

                    if let line {
                        Text(line.lineName)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer(minLength: 2)

                        Text(line.status)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(colorFromHex(line.statusColorHex))

                        Text(updatedAtLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Spacer(minLength: 0)
                        Text("No status")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .systemMedium:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Rail Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(updatedAtLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if topLines.isEmpty {
                        Spacer(minLength: 0)
                        Text("No status")
                            .font(.headline)
                        Spacer(minLength: 0)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(topLines.enumerated()), id: \.element.id) { index, line in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(colorFromHex(line.lineColorHex))
                                        .frame(width: 8, height: 8)

                                    Text("L\(line.lineNumber) \(line.lineName)")
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)

                                    Spacer(minLength: 6)

                                    Text(line.status)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(colorFromHex(line.statusColorHex))
                                        .lineLimit(1)
                                        .multilineTextAlignment(.trailing)
                                }

                                if index < topLines.count - 1 {
                                    Divider()
                                        .opacity(0.35)
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rail Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(line.map { "Line \($0.lineNumber) \($0.lineName)" } ?? "No status")
                        .font(.headline)
                        .lineLimit(1)
                    Text(line?.status ?? "Open app to refresh")
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(line.map { colorFromHex($0.statusColorHex) } ?? .secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(WidgetDeepLink.status(lineID: line?.id))
    }
}

private struct IOSNextArrivalWidgetView: View {
    let entry: IOSWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var stop: WidgetStopSnapshot? {
        if let preferred = entry.preferredStopID,
           let pinned = entry.snapshot.nearbyStops.first(where: { $0.stopId == preferred }) {
            return pinned
        }
        return entry.snapshot.nearbyStops.first
    }

    private var nextArrival: WidgetArrivalSnapshot? {
        guard let stop else { return nil }
        return entry.snapshot.arrivalsByStopID["\(stop.stopId)"]?.sorted(by: { $0.waitTime < $1.waitTime }).first
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let nextArrival {
                    Text("\(nextArrival.routeShortName) \(waitLabel(nextArrival.waitTime))")
                } else {
                    Text("No arrivals")
                }
            case .accessoryCircular:
                ZStack {
                    Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    Text(nextArrival.map { waitLabel($0.waitTime) } ?? "--")
                        .font(.caption2.bold())
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop?.stopName ?? "No stop selected")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    if let nextArrival {
                        Text("\(nextArrival.routeShortName) \(waitLabel(nextArrival.waitTime))")
                            .font(.caption2)
                            .lineLimit(1)
                        Text(nextArrival.headsign)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Arrival")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stop?.stopName ?? "No stop")
                        .font(.headline)
                        .lineLimit(2)
                    Text(nextArrival.map { "\($0.routeShortName) in \(waitLabel($0.waitTime))" } ?? "Open stop detail")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Stop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stop?.stopName ?? "No stop selected")
                        .font(.headline)
                        .lineLimit(1)
                    if let nextArrival {
                        Text("\(nextArrival.routeShortName) to \(nextArrival.headsign)")
                            .font(.subheadline)
                            .lineLimit(1)
                        Text("Arrives in \(waitLabel(nextArrival.waitTime))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Open a stop in the app to sync arrivals")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(stop.flatMap(WidgetDeepLink.stopDetail(stop:)))
    }
}

private struct IOSNearbyStopsWidgetView: View {
    let entry: IOSWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var stops: [WidgetStopSnapshot] {
        let limit = family == .systemLarge ? 6 : 4
        return Array(entry.snapshot.nearbyStops.prefix(limit))
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                if let first = stops.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.stopName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        if let arrival = entry.snapshot.arrivalsByStopID["\(first.stopId)"]?.sorted(by: { $0.waitTime < $1.waitTime }).first {
                            Text("\(arrival.routeShortName) \(waitLabel(arrival.waitTime))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No nearby stops")
                        .font(.caption2.weight(.semibold))
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nearby Stops")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if stops.isEmpty {
                        Text("No nearby stops")
                            .font(.headline)
                    } else {
                        ForEach(stops) { stop in
                            HStack(spacing: 8) {
                                Text(stop.stopName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if let arrival = entry.snapshot.arrivalsByStopID["\(stop.stopId)"]?.sorted(by: { $0.waitTime < $1.waitTime }).first {
                                    Text(waitLabel(arrival.waitTime))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(stops.first.flatMap(WidgetDeepLink.stopDetail(stop:)))
    }
}

private func waitLabel(_ waitTime: Int) -> String {
    if waitTime <= 0 {
        return "Now"
    }
    return "\(waitTime)m"
}

private func colorFromHex(_ rawHex: String) -> Color {
    let hex = rawHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)

    let r: Double
    let g: Double
    let b: Double

    switch hex.count {
    case 3:
        r = Double((value >> 8) & 0xF) / 15.0
        g = Double((value >> 4) & 0xF) / 15.0
        b = Double(value & 0xF) / 15.0
    case 6:
        r = Double((value >> 16) & 0xFF) / 255.0
        g = Double((value >> 8) & 0xFF) / 255.0
        b = Double(value & 0xFF) / 255.0
    default:
        return .secondary
    }

    return Color(red: r, green: g, blue: b)
}

@MainActor
private enum WidgetLocationResolver {
    static func currentCoordinate(timeout: TimeInterval = 2.5) async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }

        let authorization = CLLocationManager.authorizationStatus()
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            return nil
        }

        let requester = WidgetSingleLocationRequester()
        return await requester.request(timeout: timeout)
    }
}

@MainActor
private final class WidgetSingleLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func request(timeout: TimeInterval) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()

            timeoutTask = Task { [weak self] in
                let nanoseconds = UInt64(timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                await MainActor.run {
                    self?.finish(with: nil)
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestCoordinate = locations.last?.coordinate
        finish(with: latestCoordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        manager.delegate = nil
        continuation.resume(returning: coordinate)
    }
}

private extension View {
    @ViewBuilder
    func widgetLiquidGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            containerBackground(.clear, for: .widget)
        } else {
            containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
