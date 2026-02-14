import Foundation
import Combine

@MainActor
final class TripPlanDetailViewModel: ObservableObject {
    @Published var legs: [TripPlanLegState]
    @Published var combinedShape: [Location] = []
    @Published var combinedStops: [Stop] = []
    @Published var focusCoordinates: [Location] = []
    @Published var combinedSegments: [TripPlanMapSegment] = []
    @Published var selectedLegId: UUID?

    let preWalk: TripPlanWalkSegment?
    let postWalk: TripPlanWalkSegment?
    let originLocation: Location?
    let destinationLocation: Location?

    private let getTripRouteUseCase: GetTripRouteUseCase
    private let getRouteShapeUseCase: GetRouteShapeUseCase
    private let originLabel: String
    private let destinationLabel: String

    init(
        alternative: TripPlanAlternative,
        originLocation: Location?,
        destinationLocation: Location?,
        originLabel: String,
        destinationLabel: String,
        getTripRouteUseCase: GetTripRouteUseCase,
        getRouteShapeUseCase: GetRouteShapeUseCase
    ) {
        self.getTripRouteUseCase = getTripRouteUseCase
        self.getRouteShapeUseCase = getRouteShapeUseCase
        self.originLabel = originLabel
        self.destinationLabel = destinationLabel
        self.originLocation = originLocation
        self.destinationLocation = destinationLocation

        let legSources = TripPlanDetailViewModel.deriveLegs(from: alternative)
        self.legs = legSources.enumerated().map { index, leg in
            TripPlanLegState(
                index: index + 1,
                route: leg.route,
                tripId: leg.tripId,
                originStopId: leg.originStopId,
                destinationStopId: leg.destinationStopId,
                originStop: leg.originStop,
                destinationStop: leg.destinationStop
            )
        }

        if let originLocation,
           let firstStop = legSources.first?.originStop {
            self.preWalk = TripPlanDetailViewModel.buildWalkSegment(
                from: originLocation,
                to: firstStop.location,
                fromLabel: originLabel,
                toLabel: firstStop.stopName
            )
        } else {
            self.preWalk = nil
        }

        if let destinationLocation,
           let lastStop = legSources.last?.destinationStop {
            self.postWalk = TripPlanDetailViewModel.buildWalkSegment(
                from: lastStop.location,
                to: destinationLocation,
                fromLabel: lastStop.stopName,
                toLabel: destinationLabel
            )
        } else {
            self.postWalk = nil
        }
    }

    func load() async {
        for index in legs.indices {
            legs[index].isLoading = true
            legs[index].errorMessage = nil
        }

        for index in legs.indices {
            await loadLeg(at: index)
        }

        rebuildCombinedMap()
    }

    func reloadLeg(_ legId: UUID) async {
        guard let index = legs.firstIndex(where: { $0.id == legId }) else { return }
        await loadLeg(at: index)
        rebuildCombinedMap()
    }

    private func loadLeg(at index: Int) async {
        guard legs.indices.contains(index) else { return }
        let tripId = legs[index].tripId

        legs[index].isLoading = true
        legs[index].errorMessage = nil

        guard let tripId, !tripId.isEmpty else {
            legs[index].isLoading = false
            legs[index].errorMessage = "Trip data unavailable for this leg."
            return
        }

        do {
            let tripStop = try await getTripRouteUseCase.execute(tripId: tripId)
            let stops = sliceStops(
                tripStop.stops,
                originStopId: legs[index].originStopId,
                destinationStopId: legs[index].destinationStopId
            )
            var shape: [Location] = []
            if !tripStop.trip.shapeId.isEmpty {
                shape = try await getRouteShapeUseCase.execute(shapeId: tripStop.trip.shapeId)
            }

            legs[index].stops = stops
            legs[index].shape = shape
            legs[index].segmentCoordinates = buildLegSegment(legs[index])
            legs[index].isLoading = false

            if legs[index].id == selectedLegId {
                setFocusForLeg(legs[index])
            }
        } catch {
            legs[index].isLoading = false
            legs[index].errorMessage = error.localizedDescription
        }
    }

    func setFocusForLeg(_ leg: TripPlanLegState?) {
        selectedLegId = leg?.id
        guard let leg else {
            focusCoordinates = []
            return
        }

        if !leg.segmentCoordinates.isEmpty {
            focusCoordinates = leg.segmentCoordinates
            return
        }

        if !leg.stops.isEmpty {
            focusCoordinates = leg.stops.map { $0.location }
            return
        }

        focusCoordinates = []
    }

    func setFocusForWalk(_ walk: TripPlanWalkSegment?) {
        selectedLegId = nil
        guard let walk else {
            focusCoordinates = []
            return
        }
        focusCoordinates = [walk.fromLocation, walk.toLocation]
    }

    private func rebuildCombinedMap() {
        combinedShape = buildCombinedShape()
        combinedStops = buildCombinedStops()
        combinedSegments = buildCombinedSegments()

        if selectedLegId == nil {
            focusCoordinates = []
        }
    }

    private func buildCombinedShape() -> [Location] {
        var points: [Location] = []

        if let originLocation, let firstStop = legs.first?.originStop {
            points.append(originLocation)
            points.append(firstStop.location)
        }

        for (index, leg) in legs.enumerated() {
            let legPoints: [Location]
            if !leg.shape.isEmpty {
                legPoints = leg.shape
            } else if !leg.stops.isEmpty {
                legPoints = leg.stops.map { $0.location }
            } else if let originStop = leg.originStop, let destinationStop = leg.destinationStop {
                legPoints = [originStop.location, destinationStop.location]
            } else {
                legPoints = []
            }

            if points.last != legPoints.first, let first = legPoints.first {
                points.append(first)
            }
            points.append(contentsOf: legPoints.dropFirst())

            if index < legs.count - 1,
               let nextOrigin = legs[index + 1].originStop,
               let currentDestination = leg.destinationStop,
               currentDestination.location != nextOrigin.location {
                points.append(nextOrigin.location)
            }
        }

        if let destinationLocation, let lastStop = legs.last?.destinationStop {
            if points.last != lastStop.location {
                points.append(lastStop.location)
            }
            points.append(destinationLocation)
        }

        return points
    }

    private func buildCombinedStops() -> [Stop] {
        var stops: [Stop] = []
        var seen = Set<Int>()

        if let originLocation {
            let originStop = Stop(
                stopId: -1000,
                stopName: originLabel,
                location: originLocation,
                stopSequence: 0,
                routes: nil,
                stopCode: "",
                wheelchairBoarding: 0
            )
            stops.append(originStop)
            seen.insert(originStop.stopId)
        }

        for (index, leg) in legs.enumerated() {
            if let originStop = leg.originStop {
                if !seen.contains(originStop.stopId) {
                    stops.append(originStop)
                    seen.insert(originStop.stopId)
                }
            }
            if let destinationStop = leg.destinationStop {
                if !seen.contains(destinationStop.stopId) {
                    stops.append(destinationStop)
                    seen.insert(destinationStop.stopId)
                }
            }

            if index < legs.count - 1, let transferStop = leg.destinationStop {
                if !seen.contains(transferStop.stopId) {
                    stops.append(transferStop)
                    seen.insert(transferStop.stopId)
                }
            }
        }

        if let destinationLocation {
            let destinationStop = Stop(
                stopId: -1001,
                stopName: destinationLabel,
                location: destinationLocation,
                stopSequence: 0,
                routes: nil,
                stopCode: "",
                wheelchairBoarding: 0
            )
            if !seen.contains(destinationStop.stopId) {
                stops.append(destinationStop)
                seen.insert(destinationStop.stopId)
            }
        }

        return stops
    }

    private func buildCombinedSegments() -> [TripPlanMapSegment] {
        var segments: [TripPlanMapSegment] = []

        if let originLocation, let firstStop = legs.first?.originStop {
            segments.append(TripPlanMapSegment(
                coordinates: [originLocation, firstStop.location],
                colorHex: AppColors.darkGray.hexString,
                isWalking: true
            ))
        }

        for leg in legs {
            let coordinates = buildLegSegment(leg)
            if !coordinates.isEmpty {
                segments.append(TripPlanMapSegment(
                    coordinates: coordinates,
                    colorHex: leg.route?.color ?? AppColors.accent.hexString,
                    isWalking: false
                ))
            }
        }

        if let destinationLocation, let lastStop = legs.last?.destinationStop {
            segments.append(TripPlanMapSegment(
                coordinates: [lastStop.location, destinationLocation],
                colorHex: AppColors.darkGray.hexString,
                isWalking: true
            ))
        }

        return segments
    }

    private func buildLegSegment(_ leg: TripPlanLegState) -> [Location] {
        let origin = leg.originStop?.location
        let destination = leg.destinationStop?.location

        if let origin, let destination, !leg.shape.isEmpty {
            let trimmed = trimShape(leg.shape, from: origin, to: destination)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if !leg.stops.isEmpty {
            return leg.stops.map { $0.location }
        }

        if let origin, let destination {
            return [origin, destination]
        }

        return []
    }

    private func trimShape(_ shape: [Location], from origin: Location, to destination: Location) -> [Location] {
        guard shape.count > 2 else { return shape }

        let originIndex = nearestIndex(in: shape, to: origin)
        let destinationIndex = nearestIndex(in: shape, to: destination)

        guard let originIndex, let destinationIndex else { return shape }

        if originIndex <= destinationIndex {
            return Array(shape[originIndex...destinationIndex])
        }
        return Array(shape[destinationIndex...originIndex].reversed())
    }

    private func nearestIndex(in shape: [Location], to target: Location) -> Int? {
        guard !shape.isEmpty else { return nil }
        var bestIndex: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, point) in shape.enumerated() {
            let distance = point.distance(to: target)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func sliceStops(_ stops: [Stop], originStopId: Int?, destinationStopId: Int?) -> [Stop] {
        guard let originStopId,
              let destinationStopId,
              let originIndex = stops.firstIndex(where: { $0.stopId == originStopId }),
              let destinationIndex = stops.firstIndex(where: { $0.stopId == destinationStopId }) else {
            return stops
        }

        if originIndex <= destinationIndex {
            return Array(stops[originIndex...destinationIndex])
        }

        return Array(stops[destinationIndex...originIndex])
    }

    private static func deriveLegs(from alternative: TripPlanAlternative) -> [TripPlanLeg] {
        if !alternative.legs.isEmpty {
            return alternative.legs
        }

        if alternative.type == .transfer {
            let first = TripPlanLeg(
                route: alternative.originRoute,
                tripId: alternative.originTripId,
                originStopId: alternative.originStopId,
                destinationStopId: alternative.transferStopId,
                originStop: alternative.originStop,
                destinationStop: alternative.transferStop
            )
            let second = TripPlanLeg(
                route: alternative.destinationRoute,
                tripId: alternative.destinationTripId,
                originStopId: alternative.transferStopId,
                destinationStopId: alternative.destinationStopId,
                originStop: alternative.transferStop,
                destinationStop: alternative.destinationStop
            )
            return [first, second]
        }

        return [TripPlanLeg(
            route: alternative.route,
            tripId: alternative.tripId,
            originStopId: alternative.originStopId,
            destinationStopId: alternative.destinationStopId,
            originStop: alternative.originStop,
            destinationStop: alternative.destinationStop
        )]
    }

    private static func buildWalkSegment(from: Location, to: Location, fromLabel: String, toLabel: String) -> TripPlanWalkSegment? {
        if abs(from.latitude) < 0.0001 && abs(from.longitude) < 0.0001 {
            return nil
        }
        if abs(to.latitude) < 0.0001 && abs(to.longitude) < 0.0001 {
            return nil
        }

        let distance = from.distance(to: to)
        if distance < 120 {
            return nil
        }
        let minutes = max(1, Int(ceil(distance / 80)))
        return TripPlanWalkSegment(
            fromLabel: fromLabel,
            toLabel: toLabel,
            fromLocation: from,
            toLocation: to,
            distanceMeters: distance,
            durationMinutes: minutes
        )
    }
}

struct TripPlanLegState: Identifiable {
    let id = UUID()
    let index: Int
    let route: TripPlanRoute?
    let tripId: String?
    let originStopId: Int?
    let destinationStopId: Int?
    let originStop: Stop?
    let destinationStop: Stop?

    var stops: [Stop] = []
    var shape: [Location] = []
    var segmentCoordinates: [Location] = []
    var isLoading: Bool = false
    var errorMessage: String?
}

struct TripPlanMapSegment: Identifiable {
    let id = UUID()
    let coordinates: [Location]
    let colorHex: String
    let isWalking: Bool
}

struct TripPlanWalkSegment: Identifiable {
    let id = UUID()
    let fromLabel: String
    let toLabel: String
    let fromLocation: Location
    let toLocation: Location
    let distanceMeters: Double
    let durationMinutes: Int

    var distanceText: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        }
        return "\(Int(distanceMeters)) m"
    }

    var durationText: String {
        durationMinutes == 1 ? "1 min" : "\(durationMinutes) min"
    }
}
