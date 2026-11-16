import SwiftUI

/// The journey being tracked, opened from its Live Activity.
struct TrackedJourneyScreen: View {
    let dependencies: AppDependencies
    @ObservedObject private var tracker: JourneyTracker
    @Environment(\.dismiss) private var dismiss

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _tracker = ObservedObject(wrappedValue: dependencies.journeyTracker)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let tracked = tracker.tracked {
                    TripPlanDetailView(
                        alternative: tracked.alternative,
                        originLocation: tracked.origin,
                        destinationLocation: tracked.destination,
                        originLabel: tracked.originLabel,
                        destinationLabel: tracked.destinationLabel,
                        dependencies: dependencies,
                        departureDate: tracked.serviceDay
                    )
                } else {
                    ContentUnavailableView("No journey being tracked", systemImage: "location.north.line",
                        description: Text("Open a journey in Plan a trip and tap Track this journey."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
