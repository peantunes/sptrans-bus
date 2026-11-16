import SwiftUI

/// Line colours made readable for the current appearance (see `LineColor`).
struct LinePalette {
    /// Brand colour, for badge and marker fills.
    let fill: Color
    /// Text on `fill`.
    let onFill: Color
    /// Brand colour adjusted for text on the card.
    let text: Color
    /// Brand colour adjusted for lines and rings on the card.
    let stroke: Color

    init(route: TripPlanRoute?, scheme: ColorScheme) {
        let brand = route?.color ?? ""
        let fillHex = LineColor.parse(brand) != nil ? brand : AppColors.primary.hexString
        let surface = scheme == .dark ? LineColor.darkSurface : LineColor.lightSurface
        fill = Color(hex: fillHex)
        onFill = Color(hex: LineColor.badgeText(background: fillHex, preferred: route?.textColor))
        text = Color(hex: LineColor.readable(fillHex, on: surface, minimumContrast: LineColor.textContrast) ?? fillHex)
        stroke = Color(hex: LineColor.readable(fillHex, on: surface, minimumContrast: LineColor.graphicContrast) ?? fillHex)
    }
}

struct LineBadge: View {
    let route: TripPlanRoute?
    var systemImage: String? = nil
    @Environment(\.colorScheme) private var scheme

    private var name: String {
        if let short = route?.shortName, !short.isEmpty { return short }
        return route?.routeId ?? NSLocalizedString("Line", comment: "")
    }

    var body: some View {
        let palette = LinePalette(route: route, scheme: scheme)
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(name).lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(palette.onFill)
        .background(palette.fill, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// One vehicle leg: header, then boarding, intermediate and alighting stops, in a single card.
struct TripPlanLegSection: View {
    let leg: TripPlanLegState
    var alerts: [JourneyRailLineStatus] = []
    var statusRefreshFailed = false
    let onFocus: () -> Void
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var showsAllStops = false
    private let collapsedLimit = 3

    private var details: TripPlanLeg? { leg.details }

    private var subtitle: String {
        var parts: [String] = []
        if let headsign = details?.headsign, !headsign.isEmpty {
            parts.append(String(format: NSLocalizedString("towards %@", comment: ""), headsign))
        }
        if let minutes = details?.durationMinutes {
            parts.append(TripPlanTime.duration(minutes))
        }
        return parts.joined(separator: " · ")
    }

    /// Times aligned with `leg.stops` (first and last are boarding and alighting).
    private var stopTimes: [String?] {
        guard !leg.stops.isEmpty else { return [] }
        let middle = details?.intermediateStopTimes ?? []
        if middle.count + 2 == leg.stops.count {
            return [details?.departureTime] + middle + [details?.arrivalTime]
        }
        return [details?.departureTime] + Array(repeating: nil, count: max(0, leg.stops.count - 2)) + [details?.arrivalTime]
    }

    private var intermediate: [(stop: Stop, time: String?)] {
        guard leg.stops.count > 2 else { return [] }
        let times = stopTimes
        return (1..<(leg.stops.count - 1)).map { (leg.stops[$0], times.indices.contains($0) ? times[$0] : nil) }
    }

    var body: some View {
        let palette = LinePalette(route: leg.route, scheme: scheme)
        JourneyCard {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: onFocus) { header(palette) }
                    .buttonStyle(.plain)
                Divider()
                timeline(palette)
                if leg.stops.isEmpty {
                    if leg.isLoading {
                        Label("Loading stops…", systemImage: "hourglass").font(.caption).foregroundStyle(.secondary)
                    } else if leg.errorMessage != nil {
                        HStack {
                            Text("Could not load the stops").font(.caption).foregroundStyle(.secondary)
                            Button("Try again", action: onRetry).font(.caption.weight(.semibold)).foregroundStyle(palette.text)
                        }
                    }
                }
                JourneyRailAlertsView(alerts: alerts, compact: true, refreshFailed: statusRefreshFailed)
            }
        }
    }

    private func header(_ palette: LinePalette) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                LineBadge(route: leg.route, systemImage: details?.systemImage ?? "bus.fill")
                if let longName = leg.route?.longName, !longName.isEmpty {
                    Text(longName).font(.headline).foregroundStyle(AppColors.text).lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let headway = details?.headwayMinutes {
                Text(String(format: NSLocalizedString("every %lld min", comment: ""), headway))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(palette.stroke.opacity(0.14), in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private func timeline(_ palette: LinePalette) -> some View {
        let middle = intermediate
        let visible = showsAllStops || middle.count <= collapsedLimit ? middle : []
        VStack(alignment: .leading, spacing: 0) {
            StopTimelineRow(time: details?.departureTime, name: leg.originStop?.stopName ?? leg.stops.first?.stopName ?? "",
                            caption: "BOARD HERE", isMajor: true, isFirst: true, isLast: false, palette: palette)
            ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                StopTimelineRow(time: item.time, name: item.stop.stopName, caption: nil,
                                isMajor: false, isFirst: false, isLast: false, palette: palette)
            }
            if middle.count > collapsedLimit {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsAllStops.toggle() }
                } label: {
                    StopToggleRow(count: middle.count, isExpanded: showsAllStops, palette: palette)
                }
                .buttonStyle(.plain)
            }
            StopTimelineRow(time: details?.arrivalTime, name: leg.destinationStop?.stopName ?? leg.stops.last?.stopName ?? "",
                            caption: "GET OFF HERE", isMajor: true, isFirst: false, isLast: true, palette: palette)
        }
    }
}

/// A stop on a leg's timeline: time, ring on the line, stop name.
private struct StopTimelineRow: View {
    let time: String?
    let name: String
    let caption: LocalizedStringKey?
    let isMajor: Bool
    let isFirst: Bool
    let isLast: Bool
    let palette: LinePalette
    @ScaledMetric(relativeTo: .title3) private var timeWidth: CGFloat = 58

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(time.map { TripPlanTime.display($0) } ?? "")
                .font(isMajor ? .title3.weight(.bold).monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(isMajor ? AppColors.text : .secondary)
                .frame(width: timeWidth, alignment: .trailing)
                .padding(.top, isMajor ? 2 : 4)
            TimelineRail(isFirst: isFirst, isLast: isLast, isMajor: isMajor, palette: palette)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(isMajor ? .headline : .subheadline)
                    .foregroundStyle(AppColors.text)
                if let caption {
                    Text(caption).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(palette.text)
                }
            }
            .padding(.top, isMajor ? 2 : 4)
            .padding(.bottom, isLast ? 0 : (isMajor ? 18 : 12))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StopToggleRow: View {
    let count: Int
    let isExpanded: Bool
    let palette: LinePalette
    @ScaledMetric(relativeTo: .title3) private var timeWidth: CGFloat = 58

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.clear.frame(width: timeWidth, height: 1)
            TimelineRail(isFirst: false, isLast: false, isMajor: false, showsRing: false, palette: palette)
            Label(isExpanded ? NSLocalizedString("Hide stops", comment: "")
                             : String(format: NSLocalizedString("%lld stops on the way", comment: ""), count),
                  systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .padding(.top, 2).padding(.bottom, 12)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
    }
}

/// Marker column: line from the previous stop, a ring, line to the next stop.
private struct TimelineRail: View {
    let isFirst: Bool
    let isLast: Bool
    let isMajor: Bool
    var showsRing = true
    let palette: LinePalette

    var body: some View {
        let ring: CGFloat = isMajor ? 22 : 14
        VStack(spacing: 0) {
            Rectangle().fill(isFirst ? Color.clear : palette.stroke.opacity(0.45))
                .frame(width: 4, height: isMajor ? 4 : 6)
            if showsRing {
                Circle().strokeBorder(palette.stroke, lineWidth: isMajor ? 5 : 3.5)
                    .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .frame(width: ring, height: ring)
            }
            Rectangle().fill(isLast ? Color.clear : palette.stroke.opacity(0.45))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 24)
    }
}

/// Walking between steps: a dashed block, unlike the vehicle cards.
struct WalkStepRow: View {
    let segment: TripPlanWalkSegment
    let toDestination: Bool
    let onFocus: () -> Void

    private var instruction: String {
        let target = toDestination ? NSLocalizedString("your destination", comment: "") : segment.toLabel
        return String(format: NSLocalizedString("Walk %@ to %@", comment: ""), segment.durationText, target)
    }

    var body: some View {
        Button(action: onFocus) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
                if let departure = segment.departureTime {
                    Text(TripPlanTime.display(departure))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppColors.text)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(instruction).font(.subheadline.weight(.medium)).foregroundStyle(AppColors.text)
                    Text(segment.distanceText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
