import Foundation

#if canImport(AnalyticsSDK)
import AnalyticsSDK
#endif

final class AppAnalyticsService: AnalyticsServiceProtocol {
    #if canImport(AnalyticsSDK)
    private let dispatcher: AnalyticsDispatcher
    #endif

    init(bundle: Bundle = .main) {
        #if canImport(AnalyticsSDK)
        dispatcher = AnalyticsDispatcher(client: AnalyticsClient(configuration: Self.configuration(from: bundle)))
        #endif
    }

    func startSessionIfNeeded() {
        #if canImport(AnalyticsSDK)
        Task(priority: .background) {
            await dispatcher.startSessionIfNeeded()
        }
        #endif
    }

    func endSession() {
        #if canImport(AnalyticsSDK)
        Task(priority: .background) {
            await dispatcher.endSessionIfNeeded()
        }
        #endif
    }

    func trackScreen(name: String, className: String?) {
        #if canImport(AnalyticsSDK)
        Task(priority: .background) {
            await dispatcher.trackScreen(name: name, className: className)
        }
        #endif
    }

    func trackEvent(name: String, properties: [String: String]) {
        #if canImport(AnalyticsSDK)
        Task(priority: .background) {
            await dispatcher.trackEvent(name: name, properties: properties)
        }
        #endif
    }
}

#if canImport(AnalyticsSDK)
private extension AppAnalyticsService {
    static func configuration(from bundle: Bundle) -> AnalyticsConfiguration {
        let apiKey = bundle
            .object(forInfoDictionaryKey: "ANALYTICS_API_KEY") as? String

        if let baseURLValue = bundle.object(forInfoDictionaryKey: "ANALYTICS_BASE_URL") as? String,
           let trimmed = trimmedString(baseURLValue),
           let parsed = URL(string: trimmed) {
            return AnalyticsConfiguration(baseURL: parsed, apiKey: trimmedString(apiKey))
        }

        return AnalyticsConfiguration(apiKey: trimmedString(apiKey))
    }

    static func trimmedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private actor AnalyticsDispatcher {
    private let client: AnalyticsClient
    private var hasStartedSession = false

    init(client: AnalyticsClient) {
        self.client = client
    }

    func startSessionIfNeeded() async {
        guard !hasStartedSession else { return }

        do {
            hasStartedSession = true
            _ = try await client.startSession()
        } catch {
            hasStartedSession = false
            print("[Analytics] startSession failed: \(error)")
        }
    }

    func endSessionIfNeeded() async {
        guard hasStartedSession else { return }

        do {
            _ = try await client.endSession()
            hasStartedSession = false
        } catch {
            print("[Analytics] endSession failed: \(error)")
        }
    }

    func trackScreen(name: String, className: String?) async {
        await startSessionIfNeeded()

        do {
            _ = try await client.trackScreenView(
                screen: AnalyticsScreen(name: name, className: className)
            )
        } catch {
            print("[Analytics] trackScreen failed: \(error)")
        }
    }

    func trackEvent(name: String, properties: [String: String]) async {
        await startSessionIfNeeded()

        let payload = properties.reduce(into: [String: JSONValue]()) { partialResult, item in
            partialResult[item.key] = .string(item.value)
        }

        do {
            _ = try await client.trackEventOrQueue(
                event: AnalyticsEvent(
                    name: name,
                    properties: payload.isEmpty ? nil : payload
                )
            )
        } catch {
            print("[Analytics] trackEvent failed: \(error)")
        }
    }
}
#endif
