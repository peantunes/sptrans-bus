import Foundation
import Combine

class StopDetailViewModel: ObservableObject {
    @Published var stop: Stop
    @Published var arrivals: [Arrival] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFavorite: Bool = false
    @Published var selectedArrival: Arrival?
    @Published var journeyStops: [Stop] = []
    @Published var journeyShape: [Location] = []
    @Published var isLoadingJourney: Bool = false
    @Published var journeyErrorMessage: String?

    private let getArrivalsUseCase: GetArrivalsUseCase
    private let getTripRouteUseCase: GetTripRouteUseCase
    private let getRouteShapeUseCase: GetRouteShapeUseCase
    private let storageService: StorageServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let watchSnapshotSync: WatchSnapshotSyncing
    private let saoPauloCalendar: Calendar
    private let serviceTimezone: TimeZone
    private let serviceDateFormatter: DateFormatter
    private let serviceTimeFormatter: DateFormatter
    private let outputTimeFormatter: DateFormatter
    private let pageSize = 20
    private var referenceDate: String?
    private var referenceTime: String?
    private var newestCursorDate: String?
    private var newestCursorTime: String?
    private var oldestCursorDate: String?
    private var oldestCursorTime: String?
    private var isLoadingNextPage = false
    private var isLoadingPreviousPage = false
    private var hasMoreNextPage = true
    private var hasMorePreviousPage = true
    private var didObserveTopBoundary = false
    private var timer: Timer?

    init(
        stop: Stop,
        getArrivalsUseCase: GetArrivalsUseCase,
        getTripRouteUseCase: GetTripRouteUseCase,
        getRouteShapeUseCase: GetRouteShapeUseCase,
        storageService: StorageServiceProtocol,
        analyticsService: AnalyticsServiceProtocol = NoOpAnalyticsService(),
        watchSnapshotSync: WatchSnapshotSyncing = NoOpWatchSnapshotSync()
    ) {
        self.stop = stop
        self.getArrivalsUseCase = getArrivalsUseCase
        self.getTripRouteUseCase = getTripRouteUseCase
        self.getRouteShapeUseCase = getRouteShapeUseCase
        self.storageService = storageService
        self.analyticsService = analyticsService
        self.watchSnapshotSync = watchSnapshotSync
        self.serviceTimezone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.serviceTimezone
        self.saoPauloCalendar = calendar

        self.serviceDateFormatter = DateFormatter()
        self.serviceDateFormatter.calendar = calendar
        self.serviceDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.serviceDateFormatter.timeZone = self.serviceTimezone
        self.serviceDateFormatter.dateFormat = "yyyy-MM-dd"

        self.serviceTimeFormatter = DateFormatter()
        self.serviceTimeFormatter.calendar = calendar
        self.serviceTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.serviceTimeFormatter.timeZone = self.serviceTimezone
        self.serviceTimeFormatter.dateFormat = "HH:mm:ss"

        self.outputTimeFormatter = DateFormatter()
        self.outputTimeFormatter.calendar = calendar
        self.outputTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.outputTimeFormatter.timeZone = self.serviceTimezone
        self.outputTimeFormatter.dateFormat = "HH:mm"
        self.isFavorite = storageService.isFavorite(stopId: stop.stopId)
    }

    func loadArrivals() {
        isLoading = true
        errorMessage = nil
        captureReferenceNow()
        resetPaginationState()
        analyticsService.trackEvent(
            name: "stop_arrivals_load_requested",
            properties: ["stop_id": "\(stop.stopId)"]
        )

        Task {
            await fetchInitialArrivals()
        }
    }

    @MainActor
    func refreshArrivals() async {
        isLoading = true
        errorMessage = nil
        captureReferenceNow()
        resetPaginationState()
        analyticsService.trackEvent(
            name: "stop_arrivals_load_requested",
            properties: [
                "stop_id": "\(stop.stopId)",
                "trigger": "refresh"
            ]
        )
        await fetchInitialArrivals()
    }

    @MainActor
    func loadNextPageIfNeeded(currentArrival: Arrival) {
        guard hasMoreNextPage else { return }
        guard !isLoadingNextPage else { return }
        guard let lastTimestamp = arrivals.last?.scheduledTimestamp else { return }
        guard currentArrival.scheduledTimestamp == lastTimestamp else { return }
        guard let cursorDate = newestCursorDate, let cursorTime = newestCursorTime else { return }

        isLoadingNextPage = true
        Task {
            await fetchPagedArrivals(direction: .next, cursorDate: cursorDate, cursorTime: cursorTime)
            await MainActor.run {
                self.isLoadingNextPage = false
            }
        }
    }

    @MainActor
    func loadPreviousPageIfNeeded(currentArrival: Arrival) {
        guard hasMorePreviousPage else { return }
        guard !isLoadingPreviousPage else { return }
        guard let firstTimestamp = arrivals.first?.scheduledTimestamp else { return }
        guard currentArrival.scheduledTimestamp == firstTimestamp else { return }
        guard let cursorDate = oldestCursorDate, let cursorTime = oldestCursorTime else { return }
        if !didObserveTopBoundary {
            didObserveTopBoundary = true
            return
        }

        isLoadingPreviousPage = true
        Task {
            await fetchPagedArrivals(direction: .previous, cursorDate: cursorDate, cursorTime: cursorTime)
            await MainActor.run {
                self.isLoadingPreviousPage = false
            }
        }
    }

    @MainActor
    private func fetchInitialArrivals() async {
        guard let referenceDate, let referenceTime else {
            isLoading = false
            errorMessage = "Could not determine Sao Paulo time."
            return
        }

        do {
            let fetchedArrivals = try await getArrivalsUseCase.execute(
                stopId: stop.stopId,
                limit: pageSize,
                date: referenceDate,
                time: referenceTime,
                direction: .next
            )
            let normalized = normalizeArrivals(from: fetchedArrivals, now: Date())
            arrivals = normalized
            hasMoreNextPage = fetchedArrivals.count >= pageSize
            hasMorePreviousPage = true
            refreshBoundaryCursors(from: fetchedArrivals)
            syncWatchArrivals()
            self.isLoading = false
            analyticsService.trackEvent(
                name: "stop_arrivals_load_succeeded",
                properties: [
                    "stop_id": "\(stop.stopId)",
                    "arrivals_count": "\(self.arrivals.count)",
                    "direction": "next"
                ]
            )
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            analyticsService.trackEvent(
                name: "stop_arrivals_load_failed",
                properties: [
                    "stop_id": "\(stop.stopId)",
                    "error": error.localizedDescription
                ]
            )
        }
    }

    @MainActor
    private func fetchPagedArrivals(direction: ArrivalsPageDirection, cursorDate: String, cursorTime: String) async {
        guard let referenceDate, let referenceTime else { return }
        do {
            let page = try await getArrivalsUseCase.execute(
                stopId: stop.stopId,
                limit: pageSize,
                date: referenceDate,
                time: referenceTime,
                cursorDate: cursorDate,
                cursorTime: cursorTime,
                direction: direction
            )

            if page.isEmpty {
                if direction == .next {
                    hasMoreNextPage = false
                } else {
                    hasMorePreviousPage = false
                }
                return
            }

            let normalized = normalizeArrivals(from: page, now: Date())
            mergeArrivals(normalized, direction: direction)
            updateBoundaryCursor(from: page, direction: direction)
            if direction == .next {
                hasMoreNextPage = page.count >= pageSize
            } else {
                hasMorePreviousPage = page.count >= pageSize
            }
            syncWatchArrivals()
        } catch {
            analyticsService.trackEvent(
                name: "stop_arrivals_pagination_failed",
                properties: [
                    "stop_id": "\(stop.stopId)",
                    "direction": direction.rawValue,
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func normalizeArrivals(from sourceArrivals: [Arrival], now: Date) -> [Arrival] {
        sourceArrivals
            .compactMap { source in
                guard let arrivalDate = scheduledDate(for: source, timeValue: source.arrivalTime) else {
                    return nil
                }

                let departureDate = scheduledDate(for: source, timeValue: source.departureTime) ?? arrivalDate
                let waitTime = max(0, Int(ceil(arrivalDate.timeIntervalSince(now) / 60)))
                let serviceDate = source.serviceDate ?? serviceDateFormatter.string(from: arrivalDate)
                let scheduledTimestamp = source.scheduledTimestamp ?? Int(arrivalDate.timeIntervalSince1970)

                return Arrival(
                    tripId: source.tripId,
                    routeId: source.routeId,
                    routeShortName: source.routeShortName,
                    routeLongName: source.routeLongName,
                    headsign: source.headsign,
                    arrivalTime: outputTimeFormatter.string(from: arrivalDate),
                    departureTime: outputTimeFormatter.string(from: departureDate),
                    stopId: source.stopId,
                    stopSequence: source.stopSequence,
                    routeType: source.routeType,
                    routeColor: source.routeColor,
                    routeTextColor: source.routeTextColor,
                    frequency: source.frequency,
                    waitTime: waitTime,
                    serviceDate: serviceDate,
                    scheduledTimestamp: scheduledTimestamp
                )
            }
            .sorted { lhs, rhs in
                if let lhsTs = lhs.scheduledTimestamp, let rhsTs = rhs.scheduledTimestamp, lhsTs != rhsTs {
                    return lhsTs < rhsTs
                }
                return lhs.arrivalTime < rhs.arrivalTime
            }
    }

    private func scheduledDate(for arrival: Arrival, timeValue: String) -> Date? {
        if let timestamp = arrival.scheduledTimestamp {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }

        guard let serviceDate = arrival.serviceDate ?? referenceDate else { return nil }
        guard let seconds = gtfsSeconds(from: timeValue) else { return nil }
        guard let midnight = serviceMidnight(for: serviceDate) else { return nil }
        return midnight.addingTimeInterval(TimeInterval(seconds))
    }

    private func captureReferenceNow() {
        let now = Date()
        referenceDate = serviceDateFormatter.string(from: now)
        referenceTime = serviceTimeFormatter.string(from: now)
    }

    private func resetPaginationState() {
        newestCursorDate = nil
        newestCursorTime = nil
        oldestCursorDate = nil
        oldestCursorTime = nil
        hasMoreNextPage = true
        hasMorePreviousPage = true
        isLoadingNextPage = false
        isLoadingPreviousPage = false
        didObserveTopBoundary = false
    }

    private func refreshBoundaryCursors(from rawArrivals: [Arrival]) {
        updateBoundaryCursor(from: rawArrivals, direction: .next)
        updateBoundaryCursor(from: rawArrivals, direction: .previous)
    }

    private func updateBoundaryCursor(from rawArrivals: [Arrival], direction: ArrivalsPageDirection) {
        guard !rawArrivals.isEmpty else { return }
        if direction == .next {
            guard let boundary = rawArrivals.last,
                  let serviceDate = boundary.serviceDate,
                  let shifted = shiftedCursor(serviceDate: serviceDate, gtfsTime: boundary.arrivalTime, deltaSeconds: 1) else { return }
            newestCursorDate = shifted.date
            newestCursorTime = shifted.time
            return
        }

        guard let boundary = rawArrivals.first,
              let serviceDate = boundary.serviceDate,
              let shifted = shiftedCursor(serviceDate: serviceDate, gtfsTime: boundary.arrivalTime, deltaSeconds: -1) else { return }
        oldestCursorDate = shifted.date
        oldestCursorTime = shifted.time
    }

    private func mergeArrivals(_ incoming: [Arrival], direction: ArrivalsPageDirection) {
        let combined = direction == .previous ? (incoming + arrivals) : (arrivals + incoming)
        var seen: Set<String> = []
        let deduplicated = combined.filter { arrival in
            let key = arrivalIdentity(arrival)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        arrivals = deduplicated.sorted { lhs, rhs in
            if let lhsTs = lhs.scheduledTimestamp, let rhsTs = rhs.scheduledTimestamp, lhsTs != rhsTs {
                return lhsTs < rhsTs
            }
            return lhs.arrivalTime < rhs.arrivalTime
        }
    }

    private func arrivalIdentity(_ arrival: Arrival) -> String {
        "\(arrival.tripId)|\(arrival.serviceDate ?? "")|\(arrival.scheduledTimestamp ?? 0)|\(arrival.stopSequence)"
    }

    private func shiftedCursor(serviceDate: String, gtfsTime: String, deltaSeconds: Int) -> (date: String, time: String)? {
        guard let baseDate = serviceMidnight(for: serviceDate) else { return nil }
        guard let baseSeconds = gtfsSeconds(from: gtfsTime) else { return nil }

        var totalSeconds = baseSeconds + deltaSeconds
        var cursorDate = baseDate

        while totalSeconds < 0 {
            totalSeconds += 24 * 3600
            guard let updatedDate = saoPauloCalendar.date(byAdding: .day, value: -1, to: cursorDate) else {
                return nil
            }
            cursorDate = updatedDate
        }

        let date = serviceDateFormatter.string(from: cursorDate)
        let time = gtfsTimeString(from: totalSeconds)
        return (date, time)
    }

    private func serviceMidnight(for serviceDate: String) -> Date? {
        guard let date = serviceDateFormatter.date(from: serviceDate) else { return nil }
        return saoPauloCalendar.startOfDay(for: date)
    }

    private func gtfsSeconds(from timeValue: String) -> Int? {
        let raw = timeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let clean = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? raw
        let parts = clean.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        guard let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        let second = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        return (hour * 3600) + (minute * 60) + second
    }

    private func gtfsTimeString(from totalSeconds: Int) -> String {
        let safeSeconds = max(0, totalSeconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let seconds = safeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func syncWatchArrivals() {
        let watchArrivals = self.arrivals
            .sorted { $0.waitTime < $1.waitTime }
            .prefix(8)
            .map { arrival in
                WatchArrivalSnapshot(
                    routeShortName: arrival.routeShortName,
                    headsign: arrival.headsign,
                    arrivalTime: arrival.arrivalTime,
                    waitTime: arrival.waitTime,
                    routeColorHex: arrival.routeColor
                )
            }
        watchSnapshotSync.syncArrivals(stopID: stop.stopId, arrivals: Array(watchArrivals))
    }

    func toggleFavorite() {
        if isFavorite {
            storageService.removeFavorite(stop: stop)
        } else {
            storageService.saveFavorite(stop: stop)
            watchSnapshotSync.syncPreferredStop(stopID: stop.stopId)
        }
        isFavorite.toggle()
        analyticsService.trackEvent(
            name: "stop_favorite_toggled",
            properties: [
                "stop_id": "\(stop.stopId)",
                "is_favorite": isFavorite ? "true" : "false"
            ]
        )
    }

    func trackStopDetailOpened() {
        analyticsService.trackScreen(name: "StopDetailView", className: "StopDetailView")
        analyticsService.trackEvent(
            name: "stop_detail_opened",
            properties: [
                "stop_id": "\(stop.stopId)",
                "stop_name": stop.stopName
            ]
        )
    }

    func trackJourneyDetailOpened() {
        guard let selectedArrival else { return }
        analyticsService.trackScreen(name: "JourneyDetailView", className: "JourneyDetailView")
        analyticsService.trackEvent(
            name: "journey_detail_opened",
            properties: [
                "trip_id": selectedArrival.tripId,
                "route_id": selectedArrival.routeId
            ]
        )
    }

    func startRefreshingArrivals() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.loadArrivals()
        }
    }

    func stopRefreshingArrivals() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func selectArrival(_ arrival: Arrival) {
        selectedArrival = arrival
        journeyStops = []
        journeyShape = []
        journeyErrorMessage = nil
        isLoadingJourney = true
        analyticsService.trackEvent(
            name: "stop_arrival_selected",
            properties: [
                "stop_id": "\(stop.stopId)",
                "trip_id": arrival.tripId,
                "route_id": arrival.routeId
            ]
        )

        Task {
            await loadJourney(for: arrival)
        }
    }

    @MainActor
    func clearJourneySelection() {
        selectedArrival = nil
        journeyStops = []
        journeyShape = []
        journeyErrorMessage = nil
        isLoadingJourney = false
    }

    @MainActor
    private func loadJourney(for arrival: Arrival) async {
        do {
            let tripStop = try await getTripRouteUseCase.execute(tripId: arrival.tripId)
            let shape: [Location]
            if tripStop.trip.shapeId.isEmpty {
                shape = []
            } else {
                shape = (try? await getRouteShapeUseCase.execute(shapeId: tripStop.trip.shapeId)) ?? []
            }
            journeyStops = tripStop.stops.sorted { $0.stopSequence < $1.stopSequence }
            journeyShape = shape
            journeyErrorMessage = nil
            isLoadingJourney = false
            analyticsService.trackEvent(
                name: "journey_load_succeeded",
                properties: [
                    "trip_id": arrival.tripId,
                    "stops_count": "\(journeyStops.count)",
                    "shape_points_count": "\(journeyShape.count)"
                ]
            )
        } catch {
            journeyErrorMessage = error.localizedDescription
            isLoadingJourney = false
            analyticsService.trackEvent(
                name: "journey_load_failed",
                properties: [
                    "trip_id": arrival.tripId,
                    "error": error.localizedDescription
                ]
            )
        }
    }
}
