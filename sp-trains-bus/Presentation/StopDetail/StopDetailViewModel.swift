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
    private let calendar: Calendar
    private let outputTimeFormatter: DateFormatter
    private var timer: Timer?

    init(
        stop: Stop,
        getArrivalsUseCase: GetArrivalsUseCase,
        getTripRouteUseCase: GetTripRouteUseCase,
        getRouteShapeUseCase: GetRouteShapeUseCase,
        storageService: StorageServiceProtocol,
        calendar: Calendar = .current
    ) {
        self.stop = stop
        self.getArrivalsUseCase = getArrivalsUseCase
        self.getTripRouteUseCase = getTripRouteUseCase
        self.getRouteShapeUseCase = getRouteShapeUseCase
        self.storageService = storageService
        self.calendar = calendar
        self.outputTimeFormatter = DateFormatter()
        self.outputTimeFormatter.calendar = calendar
        self.outputTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.outputTimeFormatter.dateFormat = "HH:mm"
        self.isFavorite = storageService.isFavorite(stopId: stop.stopId)
    }

    func loadArrivals() {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchArrivals()
        }
    }

    @MainActor
    func refreshArrivals() async {
        isLoading = true
        errorMessage = nil
        await fetchArrivals()
    }

    @MainActor
    private func fetchArrivals() async {
        do {
            let fetchedArrivals = try await getArrivalsUseCase.execute(stopId: stop.stopId, limit: 20)
            self.arrivals = normalizedAndExpandedArrivals(
                from: fetchedArrivals,
                now: Date(),
                displayLimit: 10
            )
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func normalizedAndExpandedArrivals(
        from sourceArrivals: [Arrival],
        now: Date,
        displayLimit: Int
    ) -> [Arrival] {
        let expanded = sourceArrivals.flatMap { expand(arrival: $0, now: now, perLineLimit: displayLimit) }

        return expanded
            .sorted { lhs, rhs in
                if lhs.waitTime == rhs.waitTime {
                    if lhs.routeShortName == rhs.routeShortName {
                        return lhs.arrivalTime < rhs.arrivalTime
                    }
                    return lhs.routeShortName < rhs.routeShortName
                }
                return lhs.waitTime < rhs.waitTime
            }
            .prefix(displayLimit)
            .map { $0 }
    }

    private func expand(arrival: Arrival, now: Date, perLineLimit: Int) -> [Arrival] {
        let firstArrivalDate = resolvedBaseDate(for: arrival, now: now)
        let firstWait = max(0, Int(firstArrivalDate.timeIntervalSince(now) / 60))

        var expanded: [Arrival] = [
            makeArrivalDisplayItem(
                from: arrival,
                arrivalDate: firstArrivalDate,
                departureDate: resolvedBaseDate(timeString: arrival.departureTime, now: now) ?? firstArrivalDate,
                waitTime: firstWait,
                keepFrequency: arrival.frequency
            )
        ]

        guard let frequency = arrival.frequency, frequency > 0 else {
            return expanded
        }

        var nextDate = firstArrivalDate
        for _ in 1..<perLineLimit {
            guard let projectedDate = calendar.date(byAdding: .minute, value: frequency, to: nextDate) else {
                continue
            }
            nextDate = projectedDate
            let projectedWait = max(0, Int(projectedDate.timeIntervalSince(now) / 60))
            expanded.append(
                makeArrivalDisplayItem(
                    from: arrival,
                    arrivalDate: projectedDate,
                    departureDate: projectedDate,
                    waitTime: projectedWait,
                    keepFrequency: frequency
                )
            )
        }

        return expanded
    }

    private func makeArrivalDisplayItem(
        from arrival: Arrival,
        arrivalDate: Date,
        departureDate: Date,
        waitTime: Int,
        keepFrequency: Int?
    ) -> Arrival {
        Arrival(
            tripId: arrival.tripId,
            routeId: arrival.routeId,
            routeShortName: arrival.routeShortName,
            routeLongName: arrival.routeLongName,
            headsign: arrival.headsign,
            arrivalTime: outputTimeFormatter.string(from: arrivalDate),
            departureTime: outputTimeFormatter.string(from: departureDate),
            stopId: arrival.stopId,
            stopSequence: arrival.stopSequence,
            routeType: arrival.routeType,
            routeColor: arrival.routeColor,
            routeTextColor: arrival.routeTextColor,
            frequency: keepFrequency,
            waitTime: waitTime
        )
    }

    private func resolvedBaseDate(for arrival: Arrival, now: Date) -> Date {
        let expectedDate = calendar.date(byAdding: .minute, value: max(arrival.waitTime, 0), to: now) ?? now

        guard let parsedDate = resolvedBaseDate(timeString: arrival.arrivalTime, now: now) else {
            return expectedDate
        }

        // Service and client clocks may differ; prefer parsed time when reasonably close.
        let toleranceSeconds: TimeInterval = 3 * 60 * 60
        let timeGap = abs(parsedDate.timeIntervalSince(expectedDate))
        return timeGap <= toleranceSeconds ? parsedDate : expectedDate
    }

    private func resolvedBaseDate(timeString: String, now: Date) -> Date? {
        let rawValue = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return nil }

        let withoutFraction = rawValue.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rawValue
        let parts = withoutFraction.split(separator: ":")
        guard parts.count >= 2,
              let rawHour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        let second = parts.count >= 3 ? (Int(parts[2]) ?? 0) : 0
        let dayOffset = max(0, rawHour / 24)
        let hour = rawHour % 24

        guard let startOfDay = calendar.dateInterval(of: .day, for: now)?.start,
              let dayShifted = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
              let composed = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: second,
                of: dayShifted
              ) else {
            return nil
        }

        // Keep a forward-looking schedule when the service wraps around midnight.
        if composed < now, let nextDay = calendar.date(byAdding: .day, value: 1, to: composed) {
            return nextDay
        }

        return composed
    }

    func toggleFavorite() {
        if isFavorite {
            storageService.removeFavorite(stop: stop)
        } else {
            storageService.saveFavorite(stop: stop)
        }
        isFavorite.toggle()
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
        } catch {
            journeyErrorMessage = error.localizedDescription
            isLoadingJourney = false
        }
    }
}
