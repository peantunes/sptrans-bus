import Foundation

enum AppIntentL10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: args)
    }
}
