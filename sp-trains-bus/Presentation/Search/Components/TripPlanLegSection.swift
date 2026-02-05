import SwiftUI

struct TripPlanLegSection: View {
    let leg: TripPlanLegState
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Text(routeBadgeText)
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

            if isExpanded {
                if leg.isLoading {
                    GlassCard {
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
                    GlassCard {
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
                    TripPlanStopsTimeline(stops: leg.stops, routeColor: routeColor)
                }
            }
        }
    }
}

struct TripPlanStopsTimeline: View {
    let stops: [Stop]
    let routeColor: Color

    @State private var isExpanded: Bool = false
    private let collapsedCount = 8

    private var displayedStops: [Stop] {
        guard !isExpanded, stops.count > collapsedCount else { return stops }
        return Array(stops.prefix(collapsedCount))
    }

    var body: some View {
        GlassCard {
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
                                .padding(.leading, 6)
                                .padding(.vertical, 8)

                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(displayedStops.indices, id: \.self) { index in
                                    TripPlanStopRow(
                                        stop: displayedStops[index],
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
    let isStart: Bool
    let isEnd: Bool
    let routeColor: Color

    var body: some View {
        let sequenceText = stop.stopSequence > 0 ? "Stop \(stop.stopSequence)" : "Stop"

        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(isStart || isEnd ? routeColor : routeColor.opacity(0.4))
                .frame(width: isStart || isEnd ? 12 : 10, height: isStart || isEnd ? 12 : 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.stopName)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)

                Text(sequenceText)
                    .font(AppFonts.caption2())
                    .foregroundColor(AppColors.text.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
    }
}
