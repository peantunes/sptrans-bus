import SwiftUI

/// Start / follow a journey: what to do now, a countdown to the next event, and other lines from
/// the stop you are at. The same state drives the Live Activity.
struct JourneyTrackingCard: View {
    @ObservedObject var tracker: JourneyTracker
    let isThisJourney: Bool
    let onStart: () -> Void

    var body: some View {
        if isThisJourney, let progress = tracker.progress {
            JourneyCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: progress.modeSymbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppColors.primary, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(progress.title).font(.headline)
                            Text(progress.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if progress.phase != .arrived, progress.nextEventDate > Date() {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Next in").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                Text(timerInterval: Date()...progress.nextEventDate, countsDown: true)
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .multilineTextAlignment(.trailing)
                            }
                            .frame(minWidth: 64, alignment: .trailing)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(0..<max(progress.stepCount, 1), id: \.self) { index in
                            Capsule()
                                .fill(index < progress.stepIndex || progress.phase == .arrived ? AppColors.primary
                                      : index == progress.stepIndex ? AppColors.primary.opacity(0.55) : Color.secondary.opacity(0.2))
                                .frame(height: 6)
                        }
                    }
                    if !tracker.alternatives.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Also from this stop to your destination").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(tracker.alternatives, id: \.self) { option in
                                    HStack(spacing: 6) {
                                        LineBadge(route: TripPlanRoute(routeId: option.lineName, shortName: option.lineName, longName: "",
                                                                       color: option.lineColorHex, textColor: option.lineTextHex))
                                        Text(option.minutes == 0 ? NSLocalizedString("now", comment: "") : "\(option.minutes) min")
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    HStack {
                        Label(progress.usesLocation ? "Following your location" : "Following the timetable",
                              systemImage: progress.usesLocation ? "location.fill" : "clock")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) { tracker.stop() } label: {
                            Text("Stop").font(.subheadline.weight(.semibold))
                        }
                        .accessibilityIdentifier("journey.stopTracking")
                    }
                    if !tracker.liveActivitiesEnabled {
                        Text("Turn on Live Activities for Due SP in Settings to follow the journey on the Lock Screen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Button(action: onStart) {
                Label("Track this journey", systemImage: "location.north.line.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(AppColors.primary, in: Capsule())
            }
            .accessibilityIdentifier("journey.startTracking")
            .accessibilityHint(Text("Shows each step on the Lock Screen and in the Dynamic Island, using your location during the journey."))
        }
    }
}
