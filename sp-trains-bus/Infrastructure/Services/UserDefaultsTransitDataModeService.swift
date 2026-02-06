import Foundation

final class UserDefaultsTransitDataModeService: TransitDataModeServiceProtocol {
    private let userDefaults: UserDefaults

    private enum Keys {
        static let useLocalTransitData = "useLocalTransitData"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var useLocalData: Bool {
        get { userDefaults.bool(forKey: Keys.useLocalTransitData) }
        set { userDefaults.set(newValue, forKey: Keys.useLocalTransitData) }
    }
}
