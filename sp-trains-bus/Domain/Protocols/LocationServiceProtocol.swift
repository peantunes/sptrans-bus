import Foundation

protocol LocationServiceProtocol {
    func requestLocationPermission()
    func getCurrentLocation() -> Location?
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
