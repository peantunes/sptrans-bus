import Foundation

protocol LocationServiceProtocol {
    func requestLocationPermission()
    func getCurrentLocation() -> Location?
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func setLocationUpdateHandler(_ handler: ((Location) -> Void)?)
}

extension LocationServiceProtocol {
    func setLocationUpdateHandler(_ handler: ((Location) -> Void)?) {
        // Optional for implementations that do not stream updates.
    }
}
