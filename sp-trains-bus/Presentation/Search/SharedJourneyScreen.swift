import SwiftUI

/// A journey someone shared (https://sptrans.lolados.app/j/<token>), opened from a universal link.
/// It reuses the journey detail, which also shows Metro/CPTM line status.
struct SharedJourneyScreen: View {
    let token: String
    let dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @State private var shared: SharedJourney?
    @State private var error: JourneyShareError?

    var body: some View {
        NavigationStack {
            Group {
                if let shared {
                    TripPlanDetailView(
                        alternative: shared.alternative,
                        originLocation: shared.alternative.vehicleLegs.first?.originStop?.location,
                        destinationLocation: shared.alternative.vehicleLegs.last?.destinationStop?.location,
                        originLabel: shared.from,
                        destinationLabel: shared.to,
                        dependencies: dependencies,
                        departureDate: shared.departure,
                        sharedURL: shared.url
                    )
                } else if let error {
                    ContentUnavailableView {
                        Label("Shared journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        if error != .notFound {
                            Button("Try again") { Task { await load() } }
                        }
                    }
                } else {
                    ProgressView("Loading shared journey…")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        error = nil
        do {
            shared = try await dependencies.journeyShare.load(token: token)
            dependencies.analyticsService.trackEvent(name: "shared_journey_opened", properties: ["state": shared?.state ?? ""])
        } catch let shareError as JourneyShareError {
            error = shareError
        } catch {
            self.error = .unavailable
        }
    }
}
