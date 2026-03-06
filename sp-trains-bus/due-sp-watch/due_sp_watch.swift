import WidgetKit
import SwiftUI
import AppIntents

struct RailStatusEntryProvider: AppIntentTimelineProvider {
    typealias Intent = WatchRailStatusWidgetIntent
    typealias Entry = TransitEntry

    private let store = WatchSnapshotStore()
    private let apiService = SharedTransitAPIService()

    func placeholder(in context: Context) -> TransitEntry {
        TransitEntry(date: Date(), snapshot: .empty, preferredStopID: nil, selectedRailLineKey: nil)
    }

    func snapshot(for configuration: WatchRailStatusWidgetIntent, in context: Context) async -> TransitEntry {
        await loadEntry(selectedRailLineKey: configuration.selectedLineKey)
    }

    func timeline(for configuration: WatchRailStatusWidgetIntent, in context: Context) async -> Timeline<TransitEntry> {
        let entry = await loadEntry(selectedRailLineKey: configuration.selectedLineKey)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    func recommendations() -> [AppIntentRecommendation<WatchRailStatusWidgetIntent>] {
        var favoritesIntent = WatchRailStatusWidgetIntent()
        favoritesIntent.selectedLine = nil
        return [
            AppIntentRecommendation(
                intent: favoritesIntent,
                description: "Favorites first"
            )
        ]
    }

    private func loadEntry(selectedRailLineKey: String?) async -> TransitEntry {
        let preferredStopID = store.loadPreferredStopID()
        let favoriteLineIDs = store.loadFavoriteLineIDs()
        let sharedSnapshot = await apiService.fetchSnapshot(
            preferredStopID: preferredStopID,
            favoriteLineIDs: favoriteLineIDs
        )
        return TransitEntry(
            date: Date(),
            snapshot: WatchTransitSnapshot(sharedSnapshot: sharedSnapshot),
            preferredStopID: preferredStopID,
            selectedRailLineKey: selectedRailLineKey
        )
    }
}

struct TransitEntryProvider: TimelineProvider {
    private let store = WatchSnapshotStore()
    private let apiService = SharedTransitAPIService()

    func placeholder(in context: Context) -> TransitEntry {
        TransitEntry(date: Date(), snapshot: .empty, preferredStopID: nil, selectedRailLineKey: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TransitEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TransitEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func loadEntry() async -> TransitEntry {
        let preferredStopID = store.loadPreferredStopID()
        let favoriteLineIDs = store.loadFavoriteLineIDs()
        let sharedSnapshot = await apiService.fetchSnapshot(
            preferredStopID: preferredStopID,
            favoriteLineIDs: favoriteLineIDs
        )
        return TransitEntry(
            date: Date(),
            snapshot: WatchTransitSnapshot(sharedSnapshot: sharedSnapshot),
            preferredStopID: preferredStopID,
            selectedRailLineKey: nil
        )
    }
}

struct TransitEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchTransitSnapshot
    let preferredStopID: Int?
    let selectedRailLineKey: String?
}

struct due_sp_watch: Widget {
    let kind: String = "due_sp_rail_status"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WatchRailStatusWidgetIntent.self, provider: RailStatusEntryProvider()) { entry in
            RailStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Rail Status")
        .description("Favorites first. Tap edit to pin one line.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct due_sp_next_arrival: Widget {
    let kind: String = "due_sp_next_arrival"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TransitEntryProvider()) { entry in
            NextArrivalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Arrival")
        .description("Upcoming bus/train ETA for your preferred stop.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct due_sp_nearby_stops: Widget {
    let kind: String = "due_sp_nearby_stops"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TransitEntryProvider()) { entry in
            NearbyStopsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nearby Stops")
        .description("Closest stops and next arrival.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

private struct RailStatusWidgetView: View {
    let entry: TransitEntry
    @Environment(\.widgetFamily) private var family

    private var primaryLine: WatchRailLineSnapshot? {
        if let selectedKey = entry.selectedRailLineKey,
           let selected = entry.snapshot.railLines.first(where: { lineSelectionKey(for: $0) == selectedKey }) {
            return selected
        }

        if let favoriteProblem = rankedLines.first(where: { $0.isFavorite && $0.severityRawValue > 0 }) {
            return favoriteProblem
        }
        if let favorite = rankedLines.first(where: { $0.isFavorite }) {
            return favorite
        }
        if let problem = rankedLines.first(where: { $0.severityRawValue > 0 }) {
            return problem
        }
        return rankedLines.first
    }

    private var rankedLines: [WatchRailLineSnapshot] {
        entry.snapshot.railLines.sorted(by: sortLines)
    }

    private var isProblem: Bool {
        (primaryLine?.severityRawValue ?? 0) > 0
    }

    private var problemAccent: Color {
        guard let line = primaryLine else { return .secondary }
        return colorFromHex(line.statusColorHex)
    }

    private func lineSelectionKey(for line: WatchRailLineSnapshot) -> String {
        "\(line.source.lowercased())-\(line.lineNumber)"
    }

    private func sortLines(_ lhs: WatchRailLineSnapshot, _ rhs: WatchRailLineSnapshot) -> Bool {
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
                if let line = primaryLine {
                    if isProblem {
                        Text("⚠︎ L\(line.lineNumber) \(line.status)")
                    } else {
                        Text("L\(line.lineNumber) \(line.status)")
                    }
                } else {
                    Text("No status")
                }
            case .accessoryCircular:
                ZStack {
                    Circle()
                        .strokeBorder(isProblem ? problemAccent.opacity(0.75) : .secondary.opacity(0.3), lineWidth: 1.25)
                    if let line = primaryLine {
                        if isProblem {
                            VStack(spacing: 1) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("L\(line.lineNumber)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(problemAccent)
                        } else {
                            Text("L\(line.lineNumber)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                    } else {
                        Text("--")
                            .font(.caption2.bold())
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 2) {
                    if let line = primaryLine {
                        HStack(spacing: 4) {
                            Text("L\(line.lineNumber) \(line.lineName)")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            if line.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
                        }

                        HStack(spacing: 4) {
                            if isProblem {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(problemAccent)
                            }
                            Text(line.status)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(colorFromHex(line.statusColorHex))
                        }
                    } else {
                        Text("No status")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
        }
        .widgetURL(WidgetDeepLink.status(lineID: primaryLine?.id))
    }
}

private struct NextArrivalWidgetView: View {
    let entry: TransitEntry
    @Environment(\.widgetFamily) private var family

    private var selectedStop: WatchStopSnapshot? {
        if let preferredStopID = entry.preferredStopID,
           let preferred = entry.snapshot.nearbyStops.first(where: { $0.stopId == preferredStopID }) {
            return preferred
        }
        return entry.snapshot.nearbyStops.first
    }

    private var nextArrival: WatchArrivalSnapshot? {
        guard let stop = selectedStop else { return nil }
        return entry.snapshot.arrivalsByStopID["\(stop.stopId)"]?.sorted { $0.waitTime < $1.waitTime }.first
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
                    Circle()
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    if let nextArrival {
                        Text(waitLabel(nextArrival.waitTime))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.caption2.bold())
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 2) {
                    if let stop = selectedStop {
                        Text(stop.stopName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    } else {
                        Text("No stop selected")
                            .font(.caption2.weight(.semibold))
                    }

                    if let nextArrival {
                        Text("\(nextArrival.routeShortName) \(waitLabel(nextArrival.waitTime))")
                            .font(.caption2)
                            .lineLimit(1)
                        Text(nextArrival.headsign)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Open a stop to sync arrivals")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .widgetURL(selectedStop.flatMap(WidgetDeepLink.stopDetail(stop:)))
    }
}

private struct NearbyStopsWidgetView: View {
    let entry: TransitEntry
    @Environment(\.widgetFamily) private var family

    private var stops: [WatchStopSnapshot] {
        Array(entry.snapshot.nearbyStops.prefix(2))
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let first = stops.first {
                    Text(first.stopName)
                } else {
                    Text("No nearby stops")
                }
            default:
                VStack(alignment: .leading, spacing: 2) {
                    if stops.isEmpty {
                        Text("No nearby stops")
                            .font(.caption2.weight(.semibold))
                    } else {
                        ForEach(stops) { stop in
                            HStack(spacing: 4) {
                                Text(stop.stopName)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                if let arrival = entry.snapshot.arrivalsByStopID["\(stop.stopId)"]?.sorted(by: { $0.waitTime < $1.waitTime }).first {
                                    Text(waitLabel(arrival.waitTime))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
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

#Preview(as: .accessoryRectangular) {
    due_sp_watch()
} timeline: {
    TransitEntry(date: .now, snapshot: .empty, preferredStopID: nil, selectedRailLineKey: nil)
}
