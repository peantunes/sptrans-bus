import SwiftUI
import MapKit

struct TripPlanDetailView: View {
    @StateObject private var viewModel: TripPlanDetailViewModel
    let alternative: TripPlanAlternative
    let originLabel: String
    let destinationLabel: String
    @State private var expandedLegId: UUID?

    init(
        alternative: TripPlanAlternative,
        originLocation: Location?,
        destinationLocation: Location?,
        originLabel: String,
        destinationLabel: String,
        dependencies: AppDependencies
    ) {
        _viewModel = StateObject(
            wrappedValue: TripPlanDetailViewModel(
                alternative: alternative,
                originLocation: originLocation,
                destinationLocation: destinationLocation,
                originLabel: originLabel,
                destinationLabel: destinationLabel,
                getTripRouteUseCase: dependencies.getTripRouteUseCase,
                getRouteShapeUseCase: dependencies.getRouteShapeUseCase
            )
        )
        self.alternative = alternative
        self.originLabel = originLabel
        self.destinationLabel = destinationLabel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    if viewModel.combinedSegments.isEmpty && viewModel.combinedStops.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "map")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.text.opacity(0.4))

                            Text("Map preview unavailable")
                                .font(AppFonts.subheadline())
                                .foregroundColor(AppColors.text)

                            Text("We couldn't build a full route overview yet.")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        CombinedJourneyMapView(
                            segments: viewModel.combinedSegments,
                            stops: viewModel.combinedStops,
                            focusCoordinates: viewModel.focusCoordinates,
                            routeColor: AppColors.accent
                        )
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                TripPlanSummaryCard(
                    alternative: alternative,
                    originLabel: originLabel,
                    destinationLabel: destinationLabel
                )
                .padding(.horizontal)

                if let walk = viewModel.preWalk {
                    WalkSegmentCard(segment: walk, title: "Walk to boarding stop", onFocus: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedLegId = nil
                            viewModel.setFocusForWalk(walk)
                        }
                    })
                    .padding(.horizontal)
                }

                ForEach(viewModel.legs) { leg in
                    TripPlanLegSection(
                        leg: leg,
                        isExpanded: expandedLegId == leg.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedLegId == leg.id {
                                    expandedLegId = nil
                                    viewModel.setFocusForLeg(nil)
                                } else {
                                    expandedLegId = leg.id
                                    viewModel.setFocusForLeg(leg)
                                }
                            }
                        },
                        onRetry: {
                            Task { await viewModel.reloadLeg(leg.id) }
                        }
                    )
                    .padding(.horizontal)
                }

                if let walk = viewModel.postWalk {
                    WalkSegmentCard(segment: walk, title: "Walk to destination", onFocus: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedLegId = nil
                            viewModel.setFocusForWalk(walk)
                        }
                    })
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}

private struct TripPlanSummaryCard: View {
    let alternative: TripPlanAlternative
    let originLabel: String
    let destinationLabel: String

    private var departureText: String {
        alternative.departureTime ?? "--:--"
    }

    private var arrivalText: String {
        alternative.arrivalTime ?? "--:--"
    }

    private var legText: String {
        let count = alternative.legCount
        return count == 1 ? "1 leg" : "\(count) legs"
    }

    private var stopText: String {
        if let stopCount = alternative.stopCount {
            return stopCount == 1 ? "1 stop" : "\(stopCount) stops"
        }
        return "-- stops"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Departure → Arrival")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))

                        HStack(spacing: 6) {
                            Text(departureText)
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.text)

                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.text.opacity(0.5))

                            Text(arrivalText)
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.text)
                        }
                    }

                    Spacer()

                    Text(legText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.text.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    Label(stopText, systemImage: "signpost.right.fill")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))

                    if !alternative.lineSummary.isEmpty {
                        Text(alternative.lineSummary)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text)
                            .monospaced()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Route")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Text("\(originLabel) → \(destinationLabel)")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct WalkSegmentCard: View {
    let segment: TripPlanWalkSegment
    let title: String
    let onFocus: () -> Void

    var body: some View {
        Button(action: onFocus) {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(10)
                        .background(AppColors.primary.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text)

                        Text("\(segment.fromLabel) → \(segment.toLabel)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.6))
                            .lineLimit(2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(segment.distanceText)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.8))

                        Text(segment.durationText)
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.6))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CombinedJourneyMapView: UIViewRepresentable {
    let segments: [TripPlanMapSegment]
    let stops: [Stop]
    let focusCoordinates: [Location]
    let routeColor: Color

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
        context.coordinator.resetStyles()

        let allCoordinates = segments.flatMap { $0.coordinates }.map { $0.toCLLocationCoordinate2D() }
        let fallbackCoordinates = stops.map { $0.location.toCLLocationCoordinate2D() }

        if allCoordinates.count > 1 {
            for segment in segments {
                guard segment.coordinates.count > 1 else { continue }
                let coordinates = segment.coordinates.map { $0.toCLLocationCoordinate2D() }
                let points = coordinates.map { MKMapPoint($0) }
                let polyline = MKPolyline(points: points, count: points.count)
                context.coordinator.setStyle(
                    for: polyline,
                    color: UIColor(Color(hex: segment.colorHex)),
                    isWalking: segment.isWalking
                )
                uiView.addOverlay(polyline)
            }
            setVisibleRegion(mapView: uiView, coordinates: allCoordinates)
        } else if let first = allCoordinates.first ?? fallbackCoordinates.first {
            let region = MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            uiView.setRegion(region, animated: false)
        }

        let focusCoords = focusCoordinates.map { $0.toCLLocationCoordinate2D() }
        if focusCoords.count > 1 {
            setVisibleRegion(mapView: uiView, coordinates: focusCoords)
        } else if let focus = focusCoords.first {
            let region = MKCoordinateRegion(
                center: focus,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            uiView.setRegion(region, animated: false)
        }

        var annotations: [JourneyOverviewAnnotation] = []

        if let firstStop = stops.first {
            annotations.append(JourneyOverviewAnnotation(
                coordinate: firstStop.location.toCLLocationCoordinate2D(),
                title: firstStop.stopName,
                kind: .start
            ))
        }

        if let lastStop = stops.last, lastStop.stopId != stops.first?.stopId {
            annotations.append(JourneyOverviewAnnotation(
                coordinate: lastStop.location.toCLLocationCoordinate2D(),
                title: lastStop.stopName,
                kind: .end
            ))
        }

        uiView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(routeColor: routeColor)
    }

    private func setVisibleRegion(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.5, height: 0.5)
            rect = rect.union(pointRect)
        }
        if !rect.isNull {
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 30, left: 24, bottom: 30, right: 24), animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let routeColor: Color
        private var overlayStyles: [ObjectIdentifier: OverlayStyle] = [:]

        init(routeColor: Color) {
            self.routeColor = routeColor
        }

        func setStyle(for overlay: MKOverlay, color: UIColor, isWalking: Bool) {
            overlayStyles[ObjectIdentifier(overlay)] = OverlayStyle(color: color, isWalking: isWalking)
        }

        func resetStyles() {
            overlayStyles.removeAll()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            if let style = overlayStyles[ObjectIdentifier(polyline)] {
                renderer.strokeColor = style.color
                renderer.lineWidth = style.isWalking ? 3 : 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                if style.isWalking {
                    renderer.lineDashPattern = [6, 6]
                }
            } else {
                renderer.strokeColor = UIColor(routeColor)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? JourneyOverviewAnnotation else { return nil }

            let identifier = "JourneyOverviewAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = false
            view.markerTintColor = UIColor(routeColor)
            view.glyphTintColor = .white
            view.displayPriority = .defaultHigh

            switch annotation.kind {
            case .start:
                view.glyphImage = UIImage(systemName: "play.fill")
            case .end:
                view.glyphImage = UIImage(systemName: "flag.fill")
            }

            return view
        }
    }
}

private final class JourneyOverviewAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case start
        case end
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

private struct OverlayStyle {
    let color: UIColor
    let isWalking: Bool
}
