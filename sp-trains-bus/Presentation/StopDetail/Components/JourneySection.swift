import SwiftUI

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
                Text("Journey")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                if selection != nil {
                    Button("Clear") {
                        onClear()
                    }
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
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
                        Text("Select a route to preview")
                            .font(AppFonts.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.text)

                        Text("Tap any arrival above to see the full journey path and stops.")
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
                        Text("Loading journey")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Text("Fetching shape and stops…")
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
                    Text("Could not load journey")
                        .font(AppFonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)

                    Text(errorMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .lineLimit(3)

                    Button("Try Again") {
                        onRetry()
                    }
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.accent)
                }
            }
        } else if let selection {
            JourneySummaryCard(selection: selection, stops: stops)

            GlassCard {
                if shape.isEmpty && stops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.text.opacity(0.4))

                        Text("Map preview unavailable")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Text("We couldn't find the route shape for this trip.")
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
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

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

                        Text("stops")
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }

                HStack(spacing: 12) {
                    Label(selection.arrivalTime, systemImage: "clock")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    if let frequency = selection.frequency {
                        Text("Every \(frequency) min")
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
                    Text("No stops available for this trip.")
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

                    if stops.count > collapsedCount {
                        Button(isExpanded ? "Show fewer stops" : "Show all stops") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
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

private struct JourneyStopRow: View {
    let stop: Stop
    let isCurrent: Bool
    let isSelected: Bool
    let isStart: Bool
    let isEnd: Bool
    let routeColor: Color

    var body: some View {
        let sequenceText = stop.stopSequence > 0 ? "Stop \(stop.stopSequence)" : "Stop"

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
                        Text("Current stop")
                            .font(AppFonts.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(routeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(routeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if isSelected && !isCurrent {
                        Text("Focused")
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
        Stop(stopId: 101, stopName: "Terminal Parque Dom Pedro II", location: Location(latitude: -23.5503, longitude: -46.6331), stopSequence: 1, stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 102, stopName: "Parada Roberto Simonsen", location: Location(latitude: -23.5512, longitude: -46.6344), stopSequence: 2, stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 103, stopName: "Rua Benjamin Constant", location: Location(latitude: -23.5526, longitude: -46.6362), stopSequence: 3, stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 104, stopName: "Maria Paula", location: Location(latitude: -23.5538, longitude: -46.6370), stopSequence: 4, stopCode: "", wheelchairBoarding: 0)
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
