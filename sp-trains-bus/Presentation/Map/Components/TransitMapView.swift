import SwiftUI
import MapKit
import CoreLocation

struct TransitMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedStop: Stop?
    let stops: [Stop]
    let railLines: [RailMapLine]
    let selectedFilter: TransitFilter

    @MainActor
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.setRegion(region, animated: false)
        return mapView
    }

    @MainActor
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isUserInteracting &&
            !mapView.region.isApproximatelyEqual(to: region) {
            context.coordinator.isProgrammaticRegionChange = true
            mapView.setRegion(region, animated: false)
            context.coordinator.isProgrammaticRegionChange = false
        }

        context.coordinator.syncRailLines(visibleRailLines, on: mapView)
        context.coordinator.syncStations(visibleStations, on: mapView)
        context.coordinator.syncStops(visibleStops, on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var visibleStops: [Stop] {
        guard selectedFilter == .bus else { return [] }
        return stops.filter { stop in
            guard stop.isRailOnlyService else { return true }
            return !isStationAlreadyShownInRailNetwork(stop: stop, stations: visibleStations)
        }
    }

    private var visibleRailLines: [RailMapLine] {
        switch selectedFilter {
        case .bus:
            return railLines
        case .metro:
            return railLines.filter { $0.system == .metro }
        case .train:
            return railLines.filter { $0.system == .cptm }
        }
    }

    private var visibleStations: [RailMapStation] {
        guard region.span.latitudeDelta <= 0.18 else { return [] }
        return visibleRailLines.flatMap(\.stations)
    }

    private func isStationAlreadyShownInRailNetwork(stop: Stop, stations: [RailMapStation]) -> Bool {
        if stations.contains(where: { $0.stopId == stop.stopId }) {
            return true
        }

        let stopName = normalizedStationName(stop.stopName)
        let stopLocation = CLLocation(latitude: stop.location.latitude, longitude: stop.location.longitude)

        return stations.contains { station in
            let stationName = normalizedStationName(station.name)
            guard stationName == stopName || stationName.contains(stopName) || stopName.contains(stationName) else {
                return false
            }

            let stationLocation = CLLocation(
                latitude: station.coordinate.latitude,
                longitude: station.coordinate.longitude
            )
            return stopLocation.distance(from: stationLocation) <= 120
        }
    }

    private func normalizedStationName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TransitMapView
        var isProgrammaticRegionChange = false
        var isUserInteracting = false
        private var railOverlaysByID: [String: RailLinePolyline] = [:]
        private var stationAnnotationsByID: [String: RailStationMapAnnotation] = [:]
        private var stopAnnotationsByID: [Int: StopMapAnnotation] = [:]

        init(parent: TransitMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if isProgrammaticRegionChange { return }
            isUserInteracting = mapView.isUserInteracting
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isProgrammaticRegionChange else { return }
            isUserInteracting = mapView.isUserInteracting
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? RailLinePolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(Color(hex: polyline.colorHex))
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let stationAnnotation = annotation as? RailStationMapAnnotation {
                let identifier = "rail-station"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: stationAnnotation, reuseIdentifier: identifier)
                view.annotation = stationAnnotation
                view.markerTintColor = UIColor(Color(hex: stationAnnotation.station.colorHex))
                view.glyphImage = UIImage(systemName: "tram.fill")
                view.displayPriority = .defaultLow
                view.canShowCallout = false
                return view
            }

            if let stopAnnotation = annotation as? StopMapAnnotation {
                let identifier = "bus-stop"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: stopAnnotation, reuseIdentifier: identifier)
                view.annotation = stopAnnotation
                view.markerTintColor = UIColor(AppColors.accent)
                view.glyphImage = UIImage(systemName: "bus.fill")
                view.displayPriority = .required
                view.canShowCallout = false
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let stopAnnotation = view.annotation as? StopMapAnnotation {
                DispatchQueue.main.async {
                    self.parent.selectedStop = stopAnnotation.stop
                }
                mapView.deselectAnnotation(stopAnnotation, animated: false)
                return
            }

            if let stationAnnotation = view.annotation as? RailStationMapAnnotation {
                DispatchQueue.main.async {
                    self.parent.selectedStop = stationAnnotation.stop
                }
                mapView.deselectAnnotation(stationAnnotation, animated: false)
            }
        }

        @MainActor
        func syncRailLines(_ lines: [RailMapLine], on mapView: MKMapView) {
            let desiredByID = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0) })
            let desiredIDs = Set(desiredByID.keys)
            let currentIDs = Set(railOverlaysByID.keys)
            let sharedIDs = desiredIDs.intersection(currentIDs)

            for id in currentIDs.subtracting(desiredIDs) {
                guard let overlay = railOverlaysByID.removeValue(forKey: id) else { continue }
                mapView.removeOverlay(overlay)
            }

            for id in sharedIDs {
                guard let line = desiredByID[id],
                      let existing = railOverlaysByID[id] else { continue }

                let fingerprint = lineFingerprint(for: line)
                guard existing.fingerprint != fingerprint || existing.colorHex != line.colorHex else {
                    continue
                }

                mapView.removeOverlay(existing)
                let updated = buildPolyline(for: line)
                railOverlaysByID[id] = updated
                mapView.addOverlay(updated)
            }

            for id in desiredIDs.subtracting(currentIDs) {
                guard let line = desiredByID[id] else { continue }
                let polyline = buildPolyline(for: line)
                railOverlaysByID[id] = polyline
                mapView.addOverlay(polyline)
            }
        }

        private func buildPolyline(for line: RailMapLine) -> RailLinePolyline {
            let polyline = RailLinePolyline(coordinates: line.polylineCoordinates, count: line.polylineCoordinates.count)
            polyline.colorHex = line.colorHex
            polyline.lineID = line.id
            polyline.fingerprint = lineFingerprint(for: line)
            return polyline
        }

        private func lineFingerprint(for line: RailMapLine) -> String {
            line.polylineCoordinates
                .map { coordinate in
                    "\(Int((coordinate.latitude * 100_000).rounded())):\(Int((coordinate.longitude * 100_000).rounded()))"
                }
                .joined(separator: "|")
        }

        @MainActor
        func syncStations(_ stations: [RailMapStation], on mapView: MKMapView) {
            let desiredByID = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
            let desiredIDs = Set(desiredByID.keys)
            let currentIDs = Set(stationAnnotationsByID.keys)

            for id in currentIDs.subtracting(desiredIDs) {
                guard let annotation = stationAnnotationsByID.removeValue(forKey: id) else { continue }
                mapView.removeAnnotation(annotation)
            }

            for id in desiredIDs.subtracting(currentIDs) {
                guard let station = desiredByID[id] else { continue }
                let annotation = RailStationMapAnnotation(station: station)
                stationAnnotationsByID[id] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        @MainActor
        func syncStops(_ stops: [Stop], on mapView: MKMapView) {
            let desiredByID = Dictionary(uniqueKeysWithValues: stops.map { ($0.stopId, $0) })
            let desiredIDs = Set(desiredByID.keys)
            let currentIDs = Set(stopAnnotationsByID.keys)

            for id in currentIDs.subtracting(desiredIDs) {
                guard let annotation = stopAnnotationsByID.removeValue(forKey: id) else { continue }
                mapView.removeAnnotation(annotation)
            }

            for id in desiredIDs.subtracting(currentIDs) {
                guard let stop = desiredByID[id] else { continue }
                let annotation = StopMapAnnotation(stop: stop)
                stopAnnotationsByID[id] = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }
}

private extension MKMapView {
    var isUserInteracting: Bool {
        gestureRecognizers?.contains(where: { recognizer in
            switch recognizer.state {
            case .began, .changed:
                return true
            default:
                return false
            }
        }) ?? false
    }
}

private final class StopMapAnnotation: NSObject, MKAnnotation {
    let stop: Stop
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(stop: Stop) {
        self.stop = stop
        coordinate = stop.location.toCLLocationCoordinate2D()
        title = stop.stopName
    }
}

private final class RailStationMapAnnotation: NSObject, MKAnnotation {
    let station: RailMapStation
    let stop: Stop
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(station: RailMapStation) {
        self.station = station
        stop = RailStationMapAnnotation.buildStop(from: station)
        id = station.id
        coordinate = station.coordinate
        title = station.name
    }

    private static func buildStop(from station: RailMapStation) -> Stop {
        Stop(
            stopId: station.stopId,
            stopName: station.name,
            location: Location(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude),
            stopSequence: 0,
            routes: station.system == .metro ? "METRÔ" : "CPTM",
            stopCode: station.id,
            wheelchairBoarding: 0
        )
    }
}

private final class RailLinePolyline: MKPolyline {
    var lineID: String = ""
    var colorHex: String = "000000"
    var fingerprint: String = ""
}

private extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, tolerance: CLLocationDegrees = 0.0001) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance &&
        abs(center.longitude - other.center.longitude) < tolerance &&
        abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
        abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
}

//#Preview {
//    @State var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
//    let sampleStops = [
//        Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0),
//        Stop(stopId: "2", stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, stopCode: "SP2", wheelchairBoarding: 0)
//    ]
//    return TransitMapView(region: $region, stops: sampleStops)
//}
