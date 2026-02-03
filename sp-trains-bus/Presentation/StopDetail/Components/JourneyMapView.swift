import SwiftUI
import MapKit

struct JourneyMapView: UIViewRepresentable {
    let shape: [Location]
    let stops: [Stop]
    let routeColor: Color
    let highlightStopId: Int?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .mutedStandard
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)

        let coordinates = !shape.isEmpty
            ? shape.map { $0.toCLLocationCoordinate2D() }
            : stops.map { $0.location.toCLLocationCoordinate2D() }

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
            uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 30, left: 24, bottom: 30, right: 24), animated: false)
        } else if let firstStop = stops.first {
            let region = MKCoordinateRegion(
                center: firstStop.location.toCLLocationCoordinate2D(),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            uiView.setRegion(region, animated: false)
        }

        var annotations: [JourneyStopAnnotation] = []

        if let firstStop = stops.first {
            annotations.append(JourneyStopAnnotation(
                coordinate: firstStop.location.toCLLocationCoordinate2D(),
                title: firstStop.stopName,
                kind: .start
            ))
        }

        if let lastStop = stops.last, lastStop.stopId != stops.first?.stopId {
            annotations.append(JourneyStopAnnotation(
                coordinate: lastStop.location.toCLLocationCoordinate2D(),
                title: lastStop.stopName,
                kind: .end
            ))
        }

        if let highlightStopId,
           let currentStop = stops.first(where: { $0.stopId == highlightStopId }) {
            annotations.append(JourneyStopAnnotation(
                coordinate: currentStop.location.toCLLocationCoordinate2D(),
                title: currentStop.stopName,
                kind: .current
            ))
        }

        uiView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: JourneyMapView

        init(_ parent: JourneyMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.routeColor)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? JourneyStopAnnotation else { return nil }

            let identifier = "JourneyStopAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = false
            view.markerTintColor = UIColor(parent.routeColor)
            view.glyphTintColor = .white

            switch annotation.kind {
            case .start:
                view.glyphImage = UIImage(systemName: "play.fill")
                view.displayPriority = .defaultHigh
            case .end:
                view.glyphImage = UIImage(systemName: "flag.fill")
                view.displayPriority = .defaultHigh
            case .current:
                view.glyphImage = UIImage(systemName: "location.fill")
                view.displayPriority = .required
            }

            return view
        }
    }
}

final class JourneyStopAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case start
        case end
        case current
    }

    let coordinate: CLLocationCoordinate2D
    let title: String?
    let kind: Kind

    init(coordinate: CLLocationCoordinate2D, title: String?, kind: Kind) {
        self.coordinate = coordinate
        self.title = title
        self.kind = kind
        super.init()
    }
}

#Preview {
    let stops = [
        Stop(stopId: 101, stopName: "Terminal", location: Location(latitude: -23.5503, longitude: -46.6331), stopSequence: 1, stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 102, stopName: "Parada 2", location: Location(latitude: -23.5512, longitude: -46.6344), stopSequence: 2, stopCode: "", wheelchairBoarding: 0),
        Stop(stopId: 103, stopName: "Parada 3", location: Location(latitude: -23.5526, longitude: -46.6362), stopSequence: 3, stopCode: "", wheelchairBoarding: 0)
    ]
    let shape = [
        Location(latitude: -23.5503, longitude: -46.6331),
        Location(latitude: -23.5512, longitude: -46.6344),
        Location(latitude: -23.5526, longitude: -46.6362)
    ]

    return JourneyMapView(shape: shape, stops: stops, routeColor: AppColors.accent, highlightStopId: 102)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
