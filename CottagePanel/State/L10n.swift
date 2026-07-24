import Foundation

enum L10n {
    static var language: CottageLanguage = .system

    static func text(_ key: String) -> String {
        guard let identifier = language.localizationIdentifier,
              let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
