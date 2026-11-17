import SwiftUI

struct JourneyOptionCard: View {
    let alternative: TripPlanAlternative
    var alerts: [JourneyRailLineStatus] = []
    var statusUnavailable = false
    var statusRefreshFailed = false

    var body: some View {
        JourneyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(alternative.displayDepartureTime).font(.title2.bold()).monospacedDigit()
                    Image(systemName: "arrow.right").font(.subheadline).foregroundStyle(.secondary)
                    Text(alternative.displayArrivalTime).font(.title2.bold()).monospacedDigit()
                    Spacer(minLength: 4)
                    if let duration = alternative.durationMinutes {
                        Text(TripPlanTime.duration(duration)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(alternative.transferDescription).font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(AppColors.primary.opacity(0.12), in: Capsule()).foregroundStyle(AppColors.primary)
                    Text("Scheduled estimate").font(.caption).foregroundStyle(.secondary)
                }
                JourneyMetrics(alternative: alternative, showsDuration: false)
                JourneyRailAlertsView(alerts: alerts, compact: true, unavailable: statusUnavailable, refreshFailed: statusRefreshFailed)
            }
        }
        .overlay(alignment: .leading) {
            Capsule().fill(alerts.isEmpty ? AppColors.primary : .orange).frame(width: 4).padding(.vertical, 24)
        }
        .accessibilityElement(children: .combine)
    }
}

struct JourneyMetrics: View {
    let alternative: TripPlanAlternative
    var showsDuration = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { metrics }
                VStack(alignment: .leading, spacing: 6) { metrics }
            }.font(.caption).foregroundStyle(.secondary)
            if !alternative.vehicleLegs.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { routes }
                    VStack(alignment: .leading, spacing: 6) { routes }
                }
            }
        }
    }

    @ViewBuilder private var metrics: some View {
        if showsDuration, let duration = alternative.durationMinutes {
            Label(TripPlanTime.duration(duration), systemImage: "clock")
        }
        if let minutes = alternative.walkMinutes {
            Label("Walk \(minutes) min", systemImage: "figure.walk")
        }
        if let metres = alternative.walkMeters {
            // Locale decimal separator: "1.5 km" in English, "1,5 km" in Portuguese.
            Text(metres >= 1000 ? "\((metres / 1000).formatted(.number.precision(.fractionLength(1)))) km" : String(format: "%.0f m", metres))
        }
        if let stops = alternative.stopCount, alternative.type != .walk {
            Text(stops == 1 ? NSLocalizedString("1 stop", comment: "") : String(format: NSLocalizedString("%d stops", comment: ""), stops))
        }
    }

    private var routes: some View {
        // Legacy responses synthesize legs; index identity keeps those badges stable.
        ForEach(Array(alternative.vehicleLegs.enumerated()), id: \.offset) { _, leg in
            LineBadge(route: leg.route, systemImage: leg.systemImage)
        }
    }
}
