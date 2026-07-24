import Foundation

struct CottageSettings: Codable {
    var panelWidth: Double
    var panelHeight: Double
    var showsKeyboardHints: Bool
    var opensPanelOnLaunch: Bool
    var confirmsDestructiveActions: Bool
    var restoresPanelSession: Bool
    var panelSessionRestoreSeconds: Double
    var keyboardOnlyModeEnabled: Bool
    var panelNavigationScheme: CottageKeyboardNavigationScheme
    var menuNavigationScheme: CottageKeyboardNavigationScheme
    var previewScrollScheme: CottagePreviewScrollScheme
    var favoriteActionIDs: [String]
    var hiddenActionIDs: [String]
    var customAccessoryValues: [String: String]

    static let defaults = CottageSettings(
        panelWidth: 720,
        panelHeight: 460,
        showsKeyboardHints: true,
        opensPanelOnLaunch: false,
        confirmsDestructiveActions: true,
        restoresPanelSession: true,
        panelSessionRestoreSeconds: 30,
        keyboardOnlyModeEnabled: true,
        panelNavigationScheme: .arrows,
        menuNavigationScheme: .arrows,
        previewScrollScheme: .both,
        favoriteActionIDs: [],
        hiddenActionIDs: [],
        customAccessoryValues: [:]
    )

    init(
        panelWidth: Double,
        panelHeight: Double,
        showsKeyboardHints: Bool,
        opensPanelOnLaunch: Bool,
        confirmsDestructiveActions: Bool,
        restoresPanelSession: Bool,
        panelSessionRestoreSeconds: Double,
        keyboardOnlyModeEnabled: Bool,
        panelNavigationScheme: CottageKeyboardNavigationScheme,
        menuNavigationScheme: CottageKeyboardNavigationScheme,
        previewScrollScheme: CottagePreviewScrollScheme,
        favoriteActionIDs: [String],
        hiddenActionIDs: [String],
        customAccessoryValues: [String: String]
    ) {
        self.panelWidth = panelWidth
        self.panelHeight = panelHeight
        self.showsKeyboardHints = showsKeyboardHints
        self.opensPanelOnLaunch = opensPanelOnLaunch
        self.confirmsDestructiveActions = confirmsDestructiveActions
        self.restoresPanelSession = restoresPanelSession
        self.panelSessionRestoreSeconds = panelSessionRestoreSeconds
        self.keyboardOnlyModeEnabled = keyboardOnlyModeEnabled
        self.panelNavigationScheme = panelNavigationScheme
        self.menuNavigationScheme = menuNavigationScheme
        self.previewScrollScheme = previewScrollScheme
        self.favoriteActionIDs = favoriteActionIDs
        self.hiddenActionIDs = hiddenActionIDs
        self.customAccessoryValues = customAccessoryValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        panelWidth = try container.decodeIfPresent(Double.self, forKey: .panelWidth) ?? Self.defaults.panelWidth
        panelHeight = try container.decodeIfPresent(Double.self, forKey: .panelHeight) ?? Self.defaults.panelHeight
        showsKeyboardHints = try container.decodeIfPresent(Bool.self, forKey: .showsKeyboardHints)
            ?? Self.defaults.showsKeyboardHints
        opensPanelOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .opensPanelOnLaunch)
            ?? Self.defaults.opensPanelOnLaunch
        confirmsDestructiveActions = try container.decodeIfPresent(Bool.self, forKey: .confirmsDestructiveActions)
            ?? Self.defaults.confirmsDestructiveActions
        restoresPanelSession = try container.decodeIfPresent(Bool.self, forKey: .restoresPanelSession)
            ?? Self.defaults.restoresPanelSession
        panelSessionRestoreSeconds = try container.decodeIfPresent(Double.self, forKey: .panelSessionRestoreSeconds)
            ?? Self.defaults.panelSessionRestoreSeconds
        keyboardOnlyModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyboardOnlyModeEnabled)
            ?? Self.defaults.keyboardOnlyModeEnabled
        panelNavigationScheme = try container.decodeIfPresent(
            CottageKeyboardNavigationScheme.self,
            forKey: .panelNavigationScheme
        ) ?? Self.defaults.panelNavigationScheme
        menuNavigationScheme = try container.decodeIfPresent(
            CottageKeyboardNavigationScheme.self,
            forKey: .menuNavigationScheme
        ) ?? Self.defaults.menuNavigationScheme
        previewScrollScheme = try container.decodeIfPresent(
            CottagePreviewScrollScheme.self,
            forKey: .previewScrollScheme
        ) ?? Self.defaults.previewScrollScheme
        favoriteActionIDs = try container.decodeIfPresent([String].self, forKey: .favoriteActionIDs)
            ?? Self.defaults.favoriteActionIDs
        hiddenActionIDs = try container.decodeIfPresent([String].self, forKey: .hiddenActionIDs)
            ?? Self.defaults.hiddenActionIDs
        customAccessoryValues = try container.decodeIfPresent(
            [String: String].self,
            forKey: .customAccessoryValues
        ) ?? Self.defaults.customAccessoryValues
    }
}

enum CottageSettingsStore {
    static func load() -> CottageSettings {
        ensureDirectory()

        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(CottageSettings.self, from: data) else {
            let settings = migratedSettings()
            save(settings)
            return settings
        }

        save(settings)
        return settings
    }

    static func save(_ settings: CottageSettings) {
        ensureDirectory()

        do {
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            NSLog("CottagePanel cannot write settings.json: \(error.localizedDescription)")
        }
    }

    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
    }

    private static var settingsURL: URL {
        configDirectory.appendingPathComponent("settings.json")
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func ensureDirectory() {
        guard !FileManager.default.fileExists(atPath: configDirectory.path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("CottagePanel cannot create config directory: \(error.localizedDescription)")
        }
    }

    private static func migratedSettings() -> CottageSettings {
        let defaults = UserDefaults.standard
        let savedWidth = defaults.double(forKey: "panelWidth")
        let savedHeight = defaults.double(forKey: "panelHeight")

        return CottageSettings(
            panelWidth: savedWidth > 0 ? savedWidth : CottageSettings.defaults.panelWidth,
            panelHeight: savedHeight > 0 ? savedHeight : CottageSettings.defaults.panelHeight,
            showsKeyboardHints: defaults.object(forKey: "showsKeyboardHints") as? Bool
                ?? CottageSettings.defaults.showsKeyboardHints,
            opensPanelOnLaunch: defaults.bool(forKey: "opensPanelOnLaunch"),
            confirmsDestructiveActions: CottageSettings.defaults.confirmsDestructiveActions,
            restoresPanelSession: CottageSettings.defaults.restoresPanelSession,
            panelSessionRestoreSeconds: CottageSettings.defaults.panelSessionRestoreSeconds,
            keyboardOnlyModeEnabled: CottageSettings.defaults.keyboardOnlyModeEnabled,
            panelNavigationScheme: CottageSettings.defaults.panelNavigationScheme,
            menuNavigationScheme: CottageSettings.defaults.menuNavigationScheme,
            previewScrollScheme: CottageSettings.defaults.previewScrollScheme,
            favoriteActionIDs: [],
            hiddenActionIDs: [],
            customAccessoryValues: [:]
        )
    }
}
