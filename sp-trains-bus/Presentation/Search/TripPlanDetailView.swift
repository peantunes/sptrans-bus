import SwiftUI
import MapKit

struct TripPlanDetailView: View {
    @StateObject private var viewModel: TripPlanDetailViewModel
    let alternative: TripPlanAlternative
    let departureDate: Date?
    @ObservedObject private var conditions: JourneyConditionsStore
    let originLabel: String
    let destinationLabel: String
    private let analyticsService: AnalyticsServiceProtocol

    init(
        alternative: TripPlanAlternative,
        originLocation: Location?,
        destinationLocation: Location?,
        originLabel: String,
        destinationLabel: String,
        dependencies: AppDependencies,
        departureDate: Date? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: TripPlanDetailViewModel(
                alternative: alternative,
                originLocation: originLocation,
                destinationLocation: destinationLocation,
                originLabel: originLabel,
                destinationLabel: destinationLabel,
                getTripRouteUseCase: dependencies.getTripRouteUseCase,
                getRouteShapeUseCase: dependencies.getRouteShapeUseCase,
                liveArrivals: { stopID in try await dependencies.transitRepository.getArrivals(stopId: stopID, limit: 40) }
            )
        )
        self.alternative = alternative
        self.departureDate = departureDate
        _conditions = ObservedObject(wrappedValue: dependencies.journeyConditions)
        self.originLabel = originLabel
        self.destinationLabel = destinationLabel
        self.analyticsService = dependencies.analyticsService
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripPlanSummaryCard(alternative: alternative, originLabel: originLabel,
                                    destinationLabel: destinationLabel, departureDate: departureDate)
                JourneyRailAlertsView(alerts: conditions.alerts(for: alternative),
                    unavailable: conditions.statusUnavailable(for: alternative), refreshFailed: conditions.failed)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if let live = viewModel.liveArrival, live.isFresh(at: context.date) {
                        JourneyCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Live at the boarding stop", systemImage: "dot.radiowaves.left.and.right")
                                    .font(.headline).foregroundStyle(AppColors.primary)
                                Text("Next arrival: \(live.expectedTimeText)")
                                Text("Towards \(live.headsign)").font(.subheadline)
                                Text("This is a live stop prediction, not a confirmed delay for this journey.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                HStack {
                    Text("Route overview").font(.headline)
                    Spacer()
                    Button("Refresh conditions") {
                        Task {
                            await conditions.refresh()
                            await viewModel.refreshLiveArrival()
                        }
                    }.font(.caption).disabled(conditions.isLoading || viewModel.isLoadingLiveArrival)
                }
                JourneyCard {
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

                ForEach(viewModel.segments.indices, id: \.self) { index in
                    switch viewModel.segments[index] {
                    case .walk(let walk):
                        WalkStepRow(segment: walk,
                                    toDestination: alternative.type == .walk || index == viewModel.segments.count - 1,
                                    onFocus: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.setFocusForWalk(walk)
                            }
                        })
                    case .transit(let legIndex):
                        if viewModel.legs.indices.contains(legIndex) {
                            legSection(viewModel.legs[legIndex])
                        }
                    }
                }
                Text("Walking paths on the map are approximate.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            analyticsService.trackScreen(name: "TripPlanDetailView", className: "TripPlanDetailView")
            analyticsService.trackEvent(
                name: "trip_plan_detail_opened",
                properties: [
                    "type": alternative.type.rawValue,
                    "legs": "\(alternative.legCount)"
                ]
            )
            await viewModel.load()
        }
        .task {
            if alternative.vehicleLegs.contains(where: { $0.railSource != nil }) { await conditions.refresh() }
            await viewModel.refreshLiveArrival()
        }
    }

    private func legSection(_ leg: TripPlanLegState) -> some View {
        TripPlanLegSection(leg: leg,
            alerts: conditions.railLines.filter { $0.isDisrupted && leg.details.map($0.matches) == true },
            statusRefreshFailed: conditions.failed, onFocus: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.setFocusForLeg(viewModel.selectedLegId == leg.id ? nil : leg)
            }
        }, onRetry: {
            Task { await viewModel.reloadLeg(leg.id) }
        })
    }
}

private struct TripPlanSummaryCard: View {
    let alternative: TripPlanAlternative
    let originLabel: String
    let destinationLabel: String
    let departureDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let date = alternative.startTimestamp.map({ Date(timeIntervalSince1970: $0) }) ?? departureDate {
                Text(date, format: .dateTime.weekday().day().month())
                    .environment(\.timeZone, TimeZone(identifier: "America/Sao_Paulo")!)
                    .font(.caption.weight(.semibold)).textCase(.uppercase).opacity(0.8)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(originLabel).font(.title2.bold())
                Image(systemName: "arrow.down").font(.title3).opacity(0.7)
                Text(destinationLabel).font(.title2.bold())
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Departure").font(.caption).opacity(0.8)
                    Text(alternative.displayDepartureTime).font(.title.bold()).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Arrival").font(.caption).opacity(0.8)
                    Text(alternative.displayArrivalTime).font(.title.bold()).monospacedDigit()
                }
            }
            HStack {
                Text(alternative.transferDescription)
                if let duration = alternative.durationMinutes { Text("· " + TripPlanTime.duration(duration)) }
            }.font(.subheadline.weight(.semibold))
            if let walking = alternative.walkMinutes {
                Label("Includes \(walking) min walking", systemImage: "figure.walk").font(.subheadline)
            }
            Label("Scheduled estimate · São Paulo time", systemImage: "clock")
                .font(.caption).opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [AppColors.primary.mix(with: .black, by: 0.5), AppColors.primary.mix(with: .black, by: 0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
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
                if !segment.isWalking {
                    // Dark outline so light line colours (e.g. Metrô L4 yellow) stand out on the map.
                    let casing = MKPolyline(points: points, count: points.count)
                    context.coordinator.setStyle(for: casing, color: UIColor.black.withAlphaComponent(0.45),
                                                 isWalking: false, width: 8)
                    uiView.addOverlay(casing)
                }
                let polyline = MKPolyline(points: points, count: points.count)
                context.coordinator.setStyle(
                    for: polyline,
                    color: UIColor(Color(hex: segment.colorHex)),
                    isWalking: segment.isWalking,
                    width: segment.isWalking ? 3 : 5
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

        func setStyle(for overlay: MKOverlay, color: UIColor, isWalking: Bool, width: CGFloat) {
            overlayStyles[ObjectIdentifier(overlay)] = OverlayStyle(color: color, isWalking: isWalking, width: width)
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
                renderer.lineWidth = style.width
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
    let width: CGFloat
}
