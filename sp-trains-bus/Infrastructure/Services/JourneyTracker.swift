import Foundation
import Combine
import CoreLocation
import ActivityKit

/// Tracks one planned journey: works out the current step from the timetable and GPS, keeps a Live
/// Activity up to date, and, at a stop, looks for other lines to the same destination.
/// Location runs in the background only while a journey is tracked (blue indicator), and stops with it.
@MainActor
final class JourneyTracker: NSObject, ObservableObject {
    struct Tracked {
        let alternative: TripPlanAlternative
        let serviceDay: Date
        let originLabel: String
        let destinationLabel: String
        let origin: Location?
        let destination: Location?
        let timeline: JourneyTimeline
    }

    @Published private(set) var tracked: Tracked?
    @Published private(set) var progress: JourneyProgress?
    @Published private(set) var alternatives: [JourneyActivityAttributes.Alternative] = []
    @Published private(set) var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    private let planTripUseCase: PlanTripUseCase
    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var activity: Activity<JourneyActivityAttributes>?
    private var ticker: Timer?
    private var alternativesKey: String?
    private var alternativesFetchedAt: Date?

    init(planTripUseCase: PlanTripUseCase) {
        self.planTripUseCase = planTripUseCase
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    var isTracking: Bool { tracked != nil }

    func isTracking(_ alternative: TripPlanAlternative) -> Bool {
        tracked?.alternative.id == alternative.id
    }

    func start(alternative: TripPlanAlternative, serviceDay: Date, originLabel: String, destinationLabel: String,
               origin: Location?, destination: Location?) {
        stop()
        let timeline = JourneyTimeline(alternative: alternative, serviceDay: serviceDay,
                                       destinationName: destinationLabel, destination: destination)
        tracked = Tracked(alternative: alternative, serviceDay: serviceDay, originLabel: originLabel,
                          destinationLabel: destinationLabel, origin: origin, destination: destination, timeline: timeline)
        startLocation()
        refresh()
        startActivity(from: originLabel, to: destinationLabel)
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        let ending = activity
        activity = nil
        if let ending {
            Task { await ending.end(nil, dismissalPolicy: .immediate) }
        }
        tracked = nil
        progress = nil
        alternatives = []
        alternativesKey = nil
    }

    // MARK: - Progress

    private func refresh() {
        guard let tracked else { return }
        let fix = lastLocation.flatMap { $0.timestamp.timeIntervalSinceNow > -120 ? $0 : nil }
        let current = JourneyProgressCalculator.progress(
            tracked.timeline,
            now: Date(),
            location: fix.map { Location(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) },
            accuracy: fix?.horizontalAccuracy
        )
        let changed = current != progress
        progress = current
        if changed { updateActivity() }
        if current.phase == .arrived, let arrival = tracked.timeline.arrival, Date() > arrival.addingTimeInterval(10 * 60) {
            stop()
            return
        }
        Task { await refreshAlternativesIfNeeded() }
    }

    /// At a boarding or transfer stop, other lines leaving from here to the same destination.
    private func refreshAlternativesIfNeeded() async {
        guard let tracked, let progress, progress.phase == .waiting, let stop = progress.stopLocation else {
            if progress?.phase != .waiting, !alternatives.isEmpty {
                alternatives = []
                updateActivity()
            }
            return
        }
        let destination = tracked.destination ?? tracked.timeline.steps.last.flatMap { step -> Location? in
            if case .ride(_, let stops) = step { return stops.last?.location }
            return nil
        }
        guard let destination else { return }
        let key = "\(progress.stepIndex)"
        if key == alternativesKey, let fetched = alternativesFetchedAt, Date().timeIntervalSince(fetched) < 120 { return }
        alternativesKey = key
        alternativesFetchedAt = Date()

        guard let plan = try? await planTripUseCase.execute(
            origin: stop, destination: destination, maxAlternatives: 6, rankingPriority: "arrives_first",
            options: TripPlanningOptions(departure: Date(), maxTransfers: 3)
        ) else { return }
        let midnight = JourneyTimeline.serviceMidnight(Date())
        let currentLine = progress.lineName
        var seen = Set<String>()
        var found: [JourneyActivityAttributes.Alternative] = []
        for option in plan.alternatives {
            guard let first = option.vehicleLegs.first, let board = first.originStop,
                  board.location.distance(to: stop) <= 300,
                  let departs = JourneyTimeline.date(first.departureTime, midnight: midnight) else { continue }
            let name = first.route?.shortName ?? first.route?.routeId ?? ""
            let minutes = Int((departs.timeIntervalSinceNow / 60).rounded(.up))
            guard !name.isEmpty, name != currentLine, minutes >= 0, minutes <= 40, seen.insert(name).inserted else { continue }
            found.append(.init(lineName: name, lineColorHex: first.route?.color ?? "", lineTextHex: first.route?.textColor ?? "", minutes: minutes))
        }
        guard self.tracked != nil, self.progress?.stepIndex == progress.stepIndex else { return }
        alternatives = Array(found.sorted { $0.minutes < $1.minutes }.prefix(3))
        updateActivity()
    }

    // MARK: - Live Activity

    private func contentState() -> JourneyActivityAttributes.ContentState? {
        guard let progress else { return nil }
        return .init(
            phase: JourneyActivityAttributes.Phase(rawValue: progress.phase.rawValue) ?? .walking,
            title: progress.title, subtitle: progress.subtitle,
            lineName: progress.lineName, lineColorHex: progress.lineColorHex, lineTextHex: progress.lineTextHex,
            modeSymbol: progress.modeSymbol, nextEventDate: progress.nextEventDate, arrivalDate: progress.arrivalDate,
            stepIndex: progress.stepIndex, stepCount: progress.stepCount, stopsLeft: progress.stopsLeft,
            alternatives: alternatives, usesLocation: progress.usesLocation
        )
    }

    private func startActivity(from: String, to: String) {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled, let state = contentState() else { return }
        let content = ActivityContent(state: state, staleDate: state.arrivalDate.addingTimeInterval(15 * 60))
        activity = try? Activity.request(attributes: JourneyActivityAttributes(from: from, to: to), content: content, pushType: nil)
    }

    private func updateActivity() {
        guard let activity, let state = contentState() else { return }
        let content = ActivityContent(state: state, staleDate: state.arrivalDate.addingTimeInterval(15 * 60))
        Task { await activity.update(content) }
    }

    // MARK: - Location

    private func startLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break   // Timetable only.
        }
    }

    private func beginUpdates() {
        guard tracked != nil else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }
}

extension JourneyTracker: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = latest
            self.refresh()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) { self.beginUpdates() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
