import Foundation
import CoreLocation

class CoreLocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var currentLocation: Location?
    private var locationUpdateCompletion: ((Location) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func getCurrentLocation() -> Location? {
        return currentLocation
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func setLocationUpdateHandler(_ handler: ((Location) -> Void)?) {
        locationUpdateCompletion = handler
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        let mapped = Location(
            latitude: latestLocation.coordinate.latitude,
            longitude: latestLocation.coordinate.longitude
        )
        currentLocation = mapped
        locationUpdateCompletion?(mapped)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization status changes here if needed
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted.")
        case .denied, .restricted:
            print("Location authorization denied or restricted.")
        case .notDetermined:
            print("Location authorization not determined.")
        @unknown default:
            print("Unknown location authorization status.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
