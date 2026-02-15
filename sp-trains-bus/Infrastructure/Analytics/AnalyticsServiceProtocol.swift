import Foundation

protocol AnalyticsServiceProtocol: AnyObject {
    func startSessionIfNeeded()
    func endSession()
    func trackScreen(name: String, className: String?)
    func trackEvent(name: String, properties: [String: String])
}

extension AnalyticsServiceProtocol {
    func trackEvent(name: String) {
        trackEvent(name: name, properties: [:])
    }
}

final class NoOpAnalyticsService: AnalyticsServiceProtocol {
    func startSessionIfNeeded() {}
    func endSession() {}
    func trackScreen(name: String, className: String?) {}
    func trackEvent(name: String, properties: [String: String]) {}
}
