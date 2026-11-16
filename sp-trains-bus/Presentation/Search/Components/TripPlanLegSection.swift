import SwiftUI

struct TripPlanLegSection: View {
    let leg: TripPlanLegState
    var alerts: [JourneyRailLineStatus] = []
    var statusRefreshFailed = false
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRetry: () -> Void

    private var routeColor: Color {
        let colorHex = leg.route?.color ?? ""
        return colorHex.isEmpty ? AppColors.accent : Color(hex: colorHex)
    }

    private var textColor: Color {
        let colorHex = leg.route?.textColor ?? ""
        return colorHex.isEmpty ? .white : Color(hex: colorHex)
    }

    private var routeBadgeText: String {
        if let shortName = leg.route?.shortName, !shortName.isEmpty {
            return shortName
        }
        return leg.route?.routeId ?? "Line"
    }

    private var stopTimes: [String?] {
        guard !leg.stops.isEmpty, let details = leg.details else { return [] }
        let middle = details.intermediateStopTimes
        if middle.count + 2 == leg.stops.count {
            return [details.departureTime] + middle + [details.arrivalTime]
        }
        return [details.departureTime] + Array(repeating: nil, count: max(0, leg.stops.count - 2)) + [details.arrivalTime]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                JourneyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Label(routeBadgeText, systemImage: leg.details?.systemImage ?? "bus.fill")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(routeColor)
                                .foregroundColor(textColor)
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Leg \(leg.index)")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.6))

                                Text(leg.route?.longName ?? "Route details")
                                    .font(AppFonts.subheadline())
                                    .foregroundColor(AppColors.text)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }

                        if let details = leg.details {
                            VStack(alignment: .leading, spacing: 4) {
                                if let headsign = details.headsign, !headsign.isEmpty {
                                    Text("Towards \(headsign)")
                                }
                                if let departure = details.departureTime, let arrival = details.arrivalTime {
                                    Text("\(TripPlanTime.display(departure)) → \(TripPlanTime.display(arrival))")
                                }
                                if let duration = details.durationMinutes {
                                    Text("\(duration) min")
                                }
                                if let headway = details.headwayMinutes {
                                    Text("Every \(headway) min (estimated)")
                                }
                            }
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Board at \(leg.originStop?.stopName ?? "boarding stop")", systemImage: "arrow.up.forward")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text)

                            Label("Drop at \(leg.destinationStop?.stopName ?? "drop-off stop")", systemImage: "arrow.down.right")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            JourneyRailAlertsView(alerts: alerts, compact: true, refreshFailed: statusRefreshFailed)
            if isExpanded {
                if leg.isLoading && leg.stops.isEmpty {
                    JourneyCard {
                        HStack(spacing: 12) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Loading leg details")
                                    .font(AppFonts.subheadline())
                                    .foregroundColor(AppColors.text)

                                Text("Fetching stops and route shape…")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.6))
                            }
                            Spacer()
                        }
                    }
                } else if let errorMessage = leg.errorMessage {
                    JourneyCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Could not load this leg")
                                .font(AppFonts.subheadline())
                                .foregroundColor(AppColors.text)

                            Text(errorMessage)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                                .lineLimit(3)

                            Button("Try again") {
                                onRetry()
                            }
                            .font(AppFonts.caption())
                            .foregroundColor(routeColor)
                        }
                    }
                } else {
                    TripPlanStopsTimeline(stops: leg.stops, routeColor: routeColor, times: stopTimes)
                }
            }
        }
    }
}

struct TripPlanStopsTimeline: View {
    let stops: [Stop]
    let routeColor: Color
    var times: [String?] = []
    @ScaledMetric private var timeWidth: CGFloat = 76
    private var timeColumnWidth: CGFloat { times.contains(where: { $0 != nil }) ? timeWidth : 0 }

    private func time(at index: Int) -> String? { times.indices.contains(index) ? times[index] : nil }

    @State private var isExpanded: Bool = false
    private let collapsedCount = 8

    private var displayedStops: [Stop] {
        guard !isExpanded, stops.count > collapsedCount else { return stops }
        return Array(stops.prefix(collapsedCount))
    }

    var body: some View {
        JourneyCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Stops")
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)

                    Spacer()

                    if !stops.isEmpty {
                        Text("\(stops.count)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.text.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if stops.isEmpty {
                    Text("No stops available for this leg.")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                } else {
                    if isExpanded || stops.count <= 2 {
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(routeColor.opacity(0.2))
                                .frame(width: 2)
                                .padding(.leading, timeColumnWidth > 0 ? timeColumnWidth + 18 : 6)
                                .padding(.vertical, 8)

                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(displayedStops.indices, id: \.self) { index in
                                    TripPlanStopRow(
                                        stop: displayedStops[index],
                                        time: time(at: index),
                                        timeColumnWidth: timeColumnWidth,
                                        isStart: index == 0,
                                        isEnd: index == displayedStops.count - 1,
                                        routeColor: routeColor
                                    )
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            TripPlanStopRow(
                                stop: stops.first!,
                                time: time(at: 0),
                                timeColumnWidth: timeColumnWidth,
                                isStart: true,
                                isEnd: false,
                                routeColor: routeColor
                            )

                            if stops.count > 2 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "ellipsis")
                                            .font(.caption)
                                            .foregroundColor(routeColor)

                                        Text("\(stops.count - 2) stops")
                                            .font(AppFonts.caption())
                                            .foregroundColor(routeColor)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(routeColor)
                                    }
                                    .padding(10)
                                    .background(routeColor.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            TripPlanStopRow(
                                stop: stops.last!,
                                time: time(at: stops.count - 1),
                                timeColumnWidth: timeColumnWidth,
                                isStart: false,
                                isEnd: true,
                                routeColor: routeColor
                            )
                        }
                    }

                    if isExpanded && stops.count > collapsedCount {
                        Button("Show fewer stops") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                        .font(AppFonts.caption())
                        .foregroundColor(routeColor)
                    } else if isExpanded && stops.count > 2 {
                        Button("Show fewer stops") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                        .font(AppFonts.caption())
                        .foregroundColor(routeColor)
                    }
                }
            }
        }
    }
}

struct TripPlanStopRow: View {
    let stop: Stop
    var time: String? = nil
    var timeColumnWidth: CGFloat = 0
    let isStart: Bool
    let isEnd: Bool
    let routeColor: Color

    var body: some View {
        let sequenceText = stop.stopSequence > 0 ? "Stop \(stop.stopSequence)" : "Stop"

        HStack(alignment: .top, spacing: 12) {
            if timeColumnWidth > 0 {
                Text(TripPlanTime.display(time))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: timeColumnWidth, alignment: .trailing)
            }
            Circle()
                .fill(isStart || isEnd ? routeColor : routeColor.opacity(0.4))
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.stopName)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)

                Text(isStart ? NSLocalizedString("Board here", comment: "") :
                    isEnd ? NSLocalizedString("Alight here", comment: "") : sequenceText)
                    .font(AppFonts.caption2())
                    .foregroundColor(AppColors.text.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
    }
}
