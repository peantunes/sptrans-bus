import MapKit

extension MKCoordinateRegion {
    // Approximate bounding box for the Sao Paulo metropolitan area.
    static let saoPauloMetro = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
        span: MKCoordinateSpan(latitudeDelta: 0.9, longitudeDelta: 0.9)
    )

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latMin = center.latitude - span.latitudeDelta / 2
        let latMax = center.latitude + span.latitudeDelta / 2
        let lonMin = center.longitude - span.longitudeDelta / 2
        let lonMax = center.longitude + span.longitudeDelta / 2

        return coordinate.latitude >= latMin && coordinate.latitude <= latMax
            && coordinate.longitude >= lonMin && coordinate.longitude <= lonMax
    }
}
