import Foundation
import UIKit
import UserNotifications

final class PushNotificationManager {
    static let shared = PushNotificationManager()

    private enum Keys {
        static let installationId = "push_installation_id"
        static let apnsToken = "push_apns_token"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var installationId: String {
        if let existing = userDefaults.string(forKey: Keys.installationId), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        userDefaults.set(generated, forKey: Keys.installationId)
        return generated
    }

    var apnsToken: String? {
        userDefaults.string(forKey: Keys.apnsToken)
    }

    func updateAPNSToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        userDefaults.set(token, forKey: Keys.apnsToken)
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let status = await currentAuthorizationStatus()
        if status != .notDetermined {
            if status == .authorized || status == .provisional || status == .ephemeral {
                registerForRemoteNotifications()
            }
            return status
        }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                registerForRemoteNotifications()
            }
        } catch {
            return .denied
        }

        return await currentAuthorizationStatus()
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

