import SwiftUI

struct UpcomingBusList: View {
    let arrivals: [Arrival]
    var onArrivalTap: ((Arrival) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if arrivals.count > 1 {
                Text("Upcoming Arrivals")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)
                    .padding(.horizontal)

                ForEach(Array(arrivals.dropFirst().enumerated()), id: \.element.id) { index, arrival in
                    UpcomingBusRow(arrival: arrival, index: index + 1)
                        .padding(.horizontal)
                        .onTapGesture {
                            onArrivalTap?(arrival)
                        }
                }
            } else if arrivals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bus")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.text.opacity(0.3))

                    Text("No upcoming arrivals")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Text("Pull down to refresh")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
}

struct UpcomingBusRow: View {
    let arrival: Arrival
    let index: Int

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Route badge
                RouteBadge(
                    routeShortName: arrival.routeShortName,
                    routeColor: arrival.routeColor,
                    routeTextColor: arrival.routeTextColor
                )

                // Route info
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrival.headsign)
                        .font(AppFonts.subheadline())
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(arrival.arrivalTime, systemImage: "clock")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))

                        if let frequency = arrival.frequency {
                            Text("• Every \(frequency) min")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.5))
                        }
                    }
                }

                Spacer()

                // Wait time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(arrival.formattedWaitTime)
                        .font(AppFonts.title3())
                        .fontWeight(.bold)
                        .foregroundColor(waitTimeColor)

                    if arrival.waitTime > 0 {
                        Text("min")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.5))
                    }
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.text.opacity(0.3))
            }
        }
    }

    private var waitTimeColor: Color {
        switch arrival.waitTimeStatus {
        case .arriving:
            return AppColors.statusAlert
        case .soon:
            return AppColors.statusWarning
        case .scheduled:
            return AppColors.statusNormal
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        ScrollView {
            UpcomingBusList(arrivals: [
                Arrival(tripId: "123", routeId: "6338-10", routeShortName: "6338-10", routeLongName: "Term. Pq. D. Pedro II", headsign: "Terminal Bandeira", arrivalTime: "10:30", departureTime: "10:30", stopId: 1, stopSequence: 1, routeType: 3, routeColor: "509E2F", routeTextColor: "FFFFFF", frequency: 15, waitTime: 3),
                Arrival(tripId: "124", routeId: "609P-10", routeShortName: "609P-10", routeLongName: "Lapa - Centro", headsign: "Jardim Paulista", arrivalTime: "10:34", departureTime: "10:34", stopId: 1, stopSequence: 2, routeType: 3, routeColor: "2196F3", routeTextColor: "FFFFFF", frequency: nil, waitTime: 4),
                Arrival(tripId: "125", routeId: "508M-10", routeShortName: "508M-10", routeLongName: "Vila Mariana", headsign: "Parque Ibirapuera", arrivalTime: "10:39", departureTime: "10:39", stopId: 1, stopSequence: 3, routeType: 3, routeColor: "9C27B0", routeTextColor: "FFFFFF", frequency: 20, waitTime: 9),
                Arrival(tripId: "126", routeId: "8707-10", routeShortName: "8707-10", routeLongName: "Santo Amaro", headsign: "Term. Santo Amaro", arrivalTime: "10:50", departureTime: "10:50", stopId: 1, stopSequence: 4, routeType: 3, routeColor: "FF5722", routeTextColor: "FFFFFF", frequency: nil, waitTime: 20)
            ])
        }
    }
}
