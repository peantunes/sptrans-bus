import SwiftUI

private func stopDetailLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

struct JourneySection: View {
    let selection: Arrival?
    let stops: [Stop]
    let shape: [Location]
    let isLoading: Bool
    let errorMessage: String?
    let currentStopId: Int
    let onClear: () -> Void
    let onRetry: () -> Void
    @State private var focusedStopId: Int?

    private var journeyColor: Color {
        guard let selection else { return AppColors.accent }
        return Color(hex: selection.routeColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stopDetailLocalized("stop_detail.journey.title"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                if selection != nil {
//                    Button("Clear") {
//                        onClear()
//                    }
//                    .font(AppFonts.caption())
//                    .foregroundColor(AppColors.text.opacity(0.6))
                }
            }

            content
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if selection == nil {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.text.opacity(0.5))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stopDetailLocalized("stop_detail.journey.select_route"))
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.text)

                        Text(stopDetailLocalized("stop_detail.journey.tap_arrival"))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        } else if isLoading {
            GlassCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stopDetailLocalized("stop_detail.journey.loading"))
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Text(stopDetailLocalized("stop_detail.journey.fetching_shape_stops"))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        } else if let errorMessage {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(stopDetailLocalized("stop_detail.journey.error_title"))
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)

                    Text(errorMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .lineLimit(3)

                    Button(stopDetailLocalized("stop_detail.try_again")) {
                        onRetry()
                    }
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.accent)
                }
            }
        } else if let selection {
            JourneySummaryCard(selection: selection, stops: stops)
//            GlassCard {

                if shape.isEmpty && stops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.text.opacity(0.4))

                        Text(stopDetailLocalized("stop_detail.journey.map_unavailable"))
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Text(stopDetailLocalized("stop_detail.journey.route_shape_missing"))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    JourneyMapView(
                        shape: shape,
                        stops: stops,
                        routeColor: journeyColor,
                        highlightStopId: focusedStopId ?? currentStopId,
                        focusedStopId: $focusedStopId
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
//            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    
                    JourneyStopsTimeline(
                        stops: stops,
                        routeColor: journeyColor,
                        currentStopId: currentStopId,
                        focusedStopId: focusedStopId,
                        onSelectStop: { stop in
                            focusedStopId = stop.stopId
                        }
                    )
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct JourneySummaryCard: View {
    let selection: Arrival
    let stops: [Stop]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RouteBadge(
                        routeShortName: selection.routeShortName,
                        routeColor: selection.routeColor,
                        routeTextColor: selection.routeTextColor
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.headsign)
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.text)
                            .lineLimit(2)

                        if !selection.routeLongName.isEmpty {
                            Text(selection.routeLongName)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(stops.count)")
                            .font(AppFonts.title3())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)

                        Text(stopDetailLocalized("stop_detail.journey.stops_count_label"))
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }

                HStack(spacing: 12) {
                    Label(selection.arrivalTime, systemImage: "clock")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    if let frequency = selection.frequency {
                        Text(String(format: stopDetailLocalized("stop_detail.every_minutes_format"), frequency))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }
            }
        }
    }
}

private struct JourneyStopsTimeline: View {
    let stops: [Stop]
    let routeColor: Color
    let currentStopId: Int
    let focusedStopId: Int?
    let onSelectStop: (Stop) -> Void

    @State private var isExpanded: Bool = false

    private let collapsedCount = 8

    private var displayedStops: [Stop] {
        guard !isExpanded, stops.count > collapsedCount else { return stops }
        return Array(stops.prefix(collapsedCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(stopDetailLocalized("stop_detail.stops.title"))
                    .font(AppFonts.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.text)
                
                Spacer()
                
                if !stops.isEmpty {
                    Text("\(stops.count)")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .padding(.horizontal, 16)
                        .background(AppColors.text.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 12)
            
            if stops.isEmpty {
                Text(stopDetailLocalized("stop_detail.journey.no_stops"))
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
            } else {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(routeColor.opacity(0.2))
                        .frame(width: 2)
                        .padding(.leading, 6)
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(displayedStops.indices, id: \.self) { index in
                            Button {
                                onSelectStop(displayedStops[index])
                            } label: {
                                JourneyStopRow(
                                    stop: displayedStops[index],
                                    isCurrent: displayedStops[index].stopId == currentStopId,
                                    isSelected: displayedStops[index].stopId == focusedStopId,
                                    isStart: index == 0,
                                    isEnd: index == displayedStops.count - 1,
                                    routeColor: routeColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                
                if stops.count > collapsedCount {
                    Button(isExpanded ? stopDetailLocalized("stop_detail.stops.show_fewer") : stopDetailLocalized("stop_detail.stops.show_all")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(AppFonts.caption())
                    .foregroundColor(routeColor)
                    .padding()
                }
            }
        }
    }
}

private struct JourneyStopRow: View {
    let stop: Stop
    let isCurrent: Bool
    let isSelected: Bool
    let isStart: Bool
    let isEnd: Bool
    let routeColor: Color

    var body: some View {
        let sequenceText = stop.stopSequence > 0
            ? String(format: stopDetailLocalized("stop_detail.stop_sequence_format"), stop.stopSequence)
            : stopDetailLocalized("stop_detail.stop_label")

        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(isSelected || isCurrent || isStart || isEnd ? routeColor : routeColor.opacity(0.4))
                .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                .overlay(
                    Circle()
                        .stroke(routeColor.opacity(isSelected || isCurrent ? 0.9 : 0.0), lineWidth: isCurrent ? 4 : 2)
                )
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.stopName)
                    .font(AppFonts.subheadline())
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(sequenceText)
                        .font(AppFonts.caption2())
                        .foregroundColor(AppColors.text.opacity(0.5))

                    if !stop.stopCode.isEmpty {
                        Text(stop.stopCode)
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.5))
                    }

                    if isCurrent {
                        Text(stopDetailLocalized("stop_detail.current_stop"))
                            .font(AppFonts.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(routeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(routeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if isSelected && !isCurrent {
                        Text(stopDetailLocalized("stop_detail.focused"))
                            .font(AppFonts.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(routeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(routeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    let stops = [
        Stop(stopId: 101, stopName: "Terminal Parque Dom Pedro II", location: Location(latitude: -23.5503, longitude: -46.6331), stopSequence: 1, routes: "METRÔ", stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 102, stopName: "Parada Roberto Simonsen", location: Location(latitude: -23.5512, longitude: -46.6344), stopSequence: 2, routes: "CTPM", stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 103, stopName: "Rua Benjamin Constant", location: Location(latitude: -23.5526, longitude: -46.6362), stopSequence: 3, routes: "CTPM", stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 104, stopName: "Maria Paula", location: Location(latitude: -23.5538, longitude: -46.6370), stopSequence: 4, routes: "XXX", stopCode: "", wheelchairBoarding: 0)
    ]

    return JourneySection(
        selection: Arrival(tripId: "123", routeId: "6338-10", routeShortName: "6338-10", routeLongName: "Term. Pq. D. Pedro II", headsign: "Terminal Bandeira", arrivalTime: "10:30", departureTime: "10:30", stopId: 1, stopSequence: 1, routeType: 3, routeColor: "509E2F", routeTextColor: "FFFFFF", frequency: 15, waitTime: 3),
        stops: stops,
        shape: [],
        isLoading: false,
        errorMessage: nil,
        currentStopId: 102,
        onClear: {},
        onRetry: {}
    )
    .padding()
}
