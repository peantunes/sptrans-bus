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

                        if arrival.isLiveFromOlhoVivo {
                            HStack(spacing: 4) {
                                Image(systemName: "dot.radiowaves.up.forward")
                                    .font(.caption)
                                Text("Live")
                                    .font(AppFonts.caption())
                            }
                            .foregroundColor(.teal)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Live data")
                        }
                    }

                    Spacer()
                }

                // Progress indicator
                BusProgressIndicator(progress: progressValue, estimatedTime: arrival.formattedWaitTime)

                // Countdown and time info
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("stop_detail.next_bus"))
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))

                        Text(arrival.arrivalTime)
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text.opacity(0.8))

                        if let frequency = arrival.frequency {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text(String(format: localized("stop_detail.every_minutes_format"), frequency))
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
                            Text(localized("stop_detail.until_arrival"))
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
        case .past:
            return AppColors.text.opacity(0.45)
        case .arriving:
            return AppColors.statusAlert
        case .soon:
            return AppColors.statusWarning
        case .scheduled:
            return AppColors.statusNormal
        }
    }

    private var progressValue: Double {
        let clamped = min(max(arrival.waitTime, 0), 10)
        return 1.0 - (Double(clamped) / 10.0)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
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
                stopId: 1,
                stopSequence: 1,
                routeType: 3,
                routeColor: "509E2F",
                routeTextColor: "FFFFFF",
                frequency: 15,
                waitTime: 3,
                isLiveFromOlhoVivo: true
            ))

            NextBusCard(arrival: Arrival(
                tripId: "124",
                routeId: "8707-10",
                routeShortName: "8707-10",
                routeLongName: "Lapa - Centro",
                headsign: "Jardim Paulista",
                arrivalTime: "10:45",
                departureTime: "10:45",
                stopId: 1,
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
