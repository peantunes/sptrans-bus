#if os(watchOS) && canImport(WidgetKit)
import WidgetKit
import SwiftUI

private struct DueSPComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchTransitSnapshot
}

private struct DueSPComplicationProvider: TimelineProvider {
    private let store = WatchSnapshotStore()

    func placeholder(in context: Context) -> DueSPComplicationEntry {
        DueSPComplicationEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (DueSPComplicationEntry) -> Void) {
        completion(DueSPComplicationEntry(date: Date(), snapshot: store.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueSPComplicationEntry>) -> Void) {
        let entry = DueSPComplicationEntry(date: Date(), snapshot: store.loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct DueSPComplicationWidget: Widget {
    let kind = "DueSPComplicationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DueSPComplicationProvider()) { entry in
            DueSPComplicationView(entry: entry)
        }
        .configurationDisplayName("Due SP")
        .description("Favorite line status and nearby ETA.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct DueSPComplicationView: View {
    let entry: DueSPComplicationEntry

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

    var body: some View {
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

    @Environment(\.widgetFamily) private var family

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
#endif
