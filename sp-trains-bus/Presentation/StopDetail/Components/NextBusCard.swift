import SwiftUI

struct NextBusCard: View {
    let arrival: Arrival

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Route badge and headsign
                HStack(alignment: .top) {
                    RouteBadge(
                        routeShortName: arrival.routeShortName,
                        routeColor: arrival.routeColor,
                        routeTextColor: arrival.routeTextColor
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(arrival.headsign)
                            .font(AppFonts.title3())
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.text)
                            .lineLimit(2)

                        if !arrival.routeLongName.isEmpty {
                            Text(arrival.routeLongName)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                // Progress indicator
                BusProgressIndicator(progress: 1 - Double(arrival.waitTime)/Double(min(arrival.waitTime, 10)), estimatedTime: arrival.formattedWaitTime)

                // Countdown and time info
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Bus")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))

                        Text(arrival.arrivalTime)
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text.opacity(0.8))

                        if let frequency = arrival.frequency {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text("Every \(frequency) min")
                                    .font(AppFonts.caption())
                            }
                            .foregroundColor(AppColors.text.opacity(0.6))
                        }
                    }

                    Spacer()

                    // Large countdown
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(arrival.formattedWaitTime)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(waitTimeColor)

                        if arrival.waitTime > 0 {
                            Text("until arrival")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
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

        VStack(spacing: 20) {
            NextBusCard(arrival: Arrival(
                tripId: "123",
                routeId: "6338-10",
                routeShortName: "6338-10",
                routeLongName: "Term. Pq. D. Pedro II",
                headsign: "Terminal Bandeira",
                arrivalTime: "10:30",
                departureTime: "10:30",
                stopId: "1",
                stopSequence: 1,
                routeType: 3,
                routeColor: "509E2F",
                routeTextColor: "FFFFFF",
                frequency: 15,
                waitTime: 3
            ))

            NextBusCard(arrival: Arrival(
                tripId: "124",
                routeId: "8707-10",
                routeShortName: "8707-10",
                routeLongName: "Lapa - Centro",
                headsign: "Jardim Paulista",
                arrivalTime: "10:45",
                departureTime: "10:45",
                stopId: "1",
                stopSequence: 2,
                routeType: 3,
                routeColor: "E91E63",
                routeTextColor: "FFFFFF",
                frequency: nil,
                waitTime: 12
            ))
        }
        .padding()
    }
}
