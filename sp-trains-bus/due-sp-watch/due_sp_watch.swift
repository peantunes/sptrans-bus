import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    private let store = WatchSnapshotStore()

    func placeholder(in context: Context) -> TransitEntry {
        TransitEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TransitEntry) -> Void) {
        let entry = TransitEntry(date: Date(), snapshot: store.loadSnapshot())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TransitEntry>) -> Void) {
        let entry = TransitEntry(date: Date(), snapshot: store.loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

struct TransitEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchTransitSnapshot
}

struct due_sp_watchEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let arrival = nearbyArrival {
                    Text("\(arrival.routeShortName) \(waitLabel(arrival.waitTime))")
                } else if let line = primaryLine {
                    Text("L\(line.lineNumber) \(line.status)")
                } else {
                    Text("Due SP")
                }

            case .accessoryCircular:
                ZStack {
                    Circle()
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)

                    if let arrival = nearbyArrival {
                        Text(waitLabel(arrival.waitTime))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    } else if let line = primaryLine {
                        Text("L\(line.lineNumber)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.caption2.bold())
                    }
                }

            default:
                VStack(alignment: .leading, spacing: 2) {
                    if let line = primaryLine {
                        Text("L\(line.lineNumber) \(line.lineName)")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Text(line.status)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(colorFromHex(line.statusColorHex))
                    } else {
                        Text("No status")
                            .font(.caption2.weight(.semibold))
                    }

                    if let stop = nearbyStop, let arrival = nearbyArrival {
                        Text("\(stop.stopName): \(waitLabel(arrival.waitTime))")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .widgetURL(WidgetDeepLink.status(lineID: primaryLine?.id))
    }

    @Environment(\.widgetFamily) private var family

    private var primaryLine: WatchRailLineSnapshot? {
        entry.snapshot.railLines.first(where: { $0.isFavorite }) ?? entry.snapshot.railLines.first
    }

    private var nearbyStop: WatchStopSnapshot? {
        entry.snapshot.nearbyStops.first
    }

    private var nearbyArrival: WatchArrivalSnapshot? {
        guard let nearbyStop else { return nil }
        return entry.snapshot.arrivalsByStopID["\(nearbyStop.stopId)"]?.sorted { $0.waitTime < $1.waitTime }.first
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
}

struct due_sp_watch: Widget {
    let kind: String = "due_sp_watch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                due_sp_watchEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                due_sp_watchEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Due SP")
        .description("Favorite line status and nearby ETA.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    due_sp_watch()
} timeline: {
    TransitEntry(date: .now, snapshot: .empty)
}
