import AppKit
import SwiftUI

@MainActor
final class CottageState: ObservableObject {
    @Published var query = "" {
        didSet {
            selectFirstIfNeeded()
        }
    }

    @Published var selectedActionID: String?
    @Published var searchFocusTrigger = 0
    @Published var actionBadgesShowText = true
    @Published var showsActionPalette = false
    @Published var showsAppMenu = false
    @Published var showsCommandActionHints = false
    @Published var statusMessage = ""
    @Published var commandShortcutActionIDs: [String] = []
    @Published var commandShortcutCustomResultIDs: [String] = []
    @Published var keyboardContext: CottageKeyboardContext = .search
    @Published var showsQuestionNumberPrefix = false
    @Published var activeCustomAction: CustomAction?
    @Published var customQuery = "" {
        didSet {
            customQueryDidChange()
        }
    }
    @Published var customResults: [CustomActionResult] = []
    @Published var selectedCustomResultID: String?
    @Published var shownCustomResultMenuID: String?
    @Published var customAccessoryValue = ""
    @Published var customFormValues: [String: String] = [:]
    @Published var customNavigationStack: [CustomPanelNavigationState] = []
    @Published var settingsShortcutRecorderFocusTrigger = 0
    @Published var focusedSettingsShortcutResultID: String?
    var customNavigationSourceResult: CustomActionResult?
    @Published var isCustomActionRunning = false
    @Published var showsCustomPopup = false
    @Published var showsActionExportSheet = false
    @Published var exportActionItems: [ActionExportItem] = []
    @Published var popupCustomAction: CustomAction?
    @Published var popupInput = ""
    @Published var popupOutput = ""
    @Published var isPopupRunning = false
    @Published var favoriteActionIDs: Set<String>
    @Published var hiddenActionIDs: Set<String>
    var customAccessoryValues: [String: String]
    @Published var panelWidth: Double {
        didSet {
            saveSettings()
        }
    }

    @Published var panelHeight: Double {
        didSet {
            saveSettings()
        }
    }

    @Published var showsKeyboardHints: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var opensPanelOnLaunch: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var confirmsDestructiveActions: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var restoresPanelSession: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var panelSessionRestoreSeconds: Double {
        didSet {
            saveSettings()
        }
    }

    @Published var appLanguage: CottageLanguage {
        didSet {
            L10n.language = appLanguage
            saveSettings()
            reloadActions()
            refreshBuiltInSettingsPanelLanguage()
        }
    }

    @Published var keyboardOnlyModeEnabled: Bool {
        didSet {
            saveSettings()
        }
    }

    @Published var panelNavigationScheme: CottageKeyboardNavigationScheme {
        didSet {
            saveSettings()
        }
    }

    @Published var menuNavigationScheme: CottageKeyboardNavigationScheme {
        didSet {
            saveSettings()
        }
    }

    @Published var previewScrollScheme: CottagePreviewScrollScheme {
        didSet {
            saveSettings()
        }
    }

    var hidePanel: (() -> Void)?
    var showSettings: (() -> Void)?
    var quitApp: (() -> Void)?
    var refreshMenuBar: (() -> Void)?

    private let fileManager = FileManager.default
    var visibleActionIDs = Set<String>()
    var visibleCustomResultIDs = Set<String>()
    private lazy var applicationActionCache = applicationActions()
    var customProcess: CustomActionProcess?
    var customNativeTask: Task<Void, Never>?
    var activeCustomProcessID: UUID?
    var customLiveWorkItem: DispatchWorkItem?
    var customResultIndex = 0
    var customPanelCaches: [String: CustomPanelCache] = [:]
    var isRestoringCustomPanelCache = false
    var statusWorkItem: DispatchWorkItem?
    var questionNumberWorkItem: DispatchWorkItem?
    private var executionCounts: [String: Int]
    private var recentExecutionIDs: [String]
    lazy var actions: [CottageAction] = sortedActions(builtInActions + applicationActionCache + customActions())

    init() {
        let settings = CottageSettingsStore.load()
        let defaults = UserDefaults.standard
        panelWidth = settings.panelWidth
        panelHeight = settings.panelHeight
        showsKeyboardHints = settings.showsKeyboardHints
        opensPanelOnLaunch = settings.opensPanelOnLaunch
        confirmsDestructiveActions = settings.confirmsDestructiveActions
        restoresPanelSession = settings.restoresPanelSession
        panelSessionRestoreSeconds = settings.panelSessionRestoreSeconds
        appLanguage = settings.appLanguage
        L10n.language = settings.appLanguage
        keyboardOnlyModeEnabled = settings.keyboardOnlyModeEnabled
        panelNavigationScheme = settings.panelNavigationScheme
        menuNavigationScheme = settings.menuNavigationScheme
        previewScrollScheme = settings.previewScrollScheme
        favoriteActionIDs = Set(settings.favoriteActionIDs)
        hiddenActionIDs = Set(settings.hiddenActionIDs)
        customAccessoryValues = settings.customAccessoryValues
        executionCounts = defaults.dictionary(forKey: "executionCounts") as? [String: Int] ?? [:]
        recentExecutionIDs = defaults.stringArray(forKey: "recentExecutionIDs") ?? []
    }
}

extension CottageState {

    var configDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
    }

    var filteredActions: [CottageAction] {
        let parsedQuery = CottageActionQuery(query)
        guard !parsedQuery.text.isEmpty else {
            return visibleActions(sortedActions(actions))
        }

        let initials = normalizedSearchText(parsedQuery.text)
        return visibleActions(sortedActions(actions.filter { action in
            switch parsedQuery.scope {
            case .all:
                return action.matches(parsedQuery.text, initials: initials)
            case .actions:
                return action.kind != .application && action.matches(parsedQuery.text, initials: initials)
            case .applications:
                return action.kind == .application && action.matches(parsedQuery.text, initials: initials)
            case .tags:
                return action.matchesTagOnly(parsedQuery.text)
            }
        }))
    }

    var selectedAction: CottageAction? {
        filteredActions.first { $0.id == selectedActionID }
    }

    var favoriteFilteredActions: [CottageAction] {
        filteredActions.filter { favoriteActionIDs.contains($0.id) }
    }

    var regularFilteredActions: [CottageAction] {
        filteredActions.filter { !favoriteActionIDs.contains($0.id) }
    }

    func reset() {
        ensureConfigDirectory()
        reloadActions()
        query = ""
        leaveCustomPanel()
        closeCustomPopup()
        showsActionPalette = false
        keyboardContext = .search
        cancelQuestionNumberPrefix()
        selectedActionID = filteredActions.first?.id
        focusSearch()
    }

    func executionCount(for action: CottageAction) -> Int {
        executionCounts[action.id, default: 0]
    }

    func recordExecution(_ action: CottageAction) {
        executionCounts[action.id, default: 0] += 1
        recentExecutionIDs.insert(action.id, at: 0)
        recentExecutionIDs = Array(recentExecutionIDs.prefix(2))
        UserDefaults.standard.set(executionCounts, forKey: "executionCounts")
        UserDefaults.standard.set(recentExecutionIDs, forKey: "recentExecutionIDs")
        actions = sortedActions(actions)
    }

    func reloadActions() {
        actions = sortedActions(builtInActions + applicationActionCache + customActions())
        refreshMenuBar?()
    }

    func sortedActions(_ actions: [CottageAction]) -> [CottageAction] {
        let pinnedID = recentExecutionIDs.count == 2 && recentExecutionIDs[0] == recentExecutionIDs[1]
            ? recentExecutionIDs[0]
            : nil

        return actions.sorted { lhs, rhs in
            if lhs.id == pinnedID {
                return true
            }
            if rhs.id == pinnedID {
                return false
            }

            let lhsFavorite = favoriteActionIDs.contains(lhs.id)
            let rhsFavorite = favoriteActionIDs.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite
            }

            let lhsCount = executionCounts[lhs.id, default: 0]
            let rhsCount = executionCounts[rhs.id, default: 0]
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }

            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func selectFirstIfNeeded() {
        guard filteredActions.contains(where: { $0.id == selectedActionID }) else {
            selectedActionID = filteredActions.first?.id
            return
        }
    }

    func ensureConfigDirectory() {
        guard !fileManager.fileExists(atPath: configDirectory.path) else {
            return
        }

        do {
            try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("CottagePanel cannot create config directory: \(error.localizedDescription)")
        }
    }

    func openConfig() {
        ensureConfigDirectory()
        NSWorkspace.shared.open(configDirectory)
    }

    func saveSettings() {
        let settings = CottageSettings(
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            showsKeyboardHints: showsKeyboardHints,
            opensPanelOnLaunch: opensPanelOnLaunch,
            confirmsDestructiveActions: confirmsDestructiveActions,
            restoresPanelSession: restoresPanelSession,
            panelSessionRestoreSeconds: panelSessionRestoreSeconds,
            appLanguage: appLanguage,
            keyboardOnlyModeEnabled: keyboardOnlyModeEnabled,
            panelNavigationScheme: panelNavigationScheme,
            menuNavigationScheme: menuNavigationScheme,
            previewScrollScheme: previewScrollScheme,
            favoriteActionIDs: Array(favoriteActionIDs).sorted(),
            hiddenActionIDs: Array(hiddenActionIDs).sorted(),
            customAccessoryValues: customAccessoryValues
        )
        CottageSettingsStore.save(settings)
    }

    private func visibleActions(_ actions: [CottageAction]) -> [CottageAction] {
        actions.filter { action in
            action.customAction != nil || !hiddenActionIDs.contains(action.id)
        }
    }

}

func openHomePath(_ path: String) {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(path)
    NSWorkspace.shared.open(url)
}

func openURL(_ string: String) {
    guard let url = URL(string: string) else {
        return
    }

    NSWorkspace.shared.open(url)
}

func normalizedSearchText(_ text: String) -> String {
    text
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}

extension CottageState {
    func openConfigDirectory() {
        ensureConfigDirectory()
        NSWorkspace.shared.open(configDirectory)
    }
}

func searchInitials(from text: String) -> String {
    var initials = ""
    var isInsideWord = false

    for character in text {
        if character.isHan {
            initials.append(transliteratedInitial(from: character))
            isInsideWord = false
        } else if character.isLetter || character.isNumber {
            if !isInsideWord {
                initials.append(String(character).lowercased())
                isInsideWord = true
            }
        } else {
            isInsideWord = false
        }
    }

    return initials
}

private func transliteratedInitial(from character: Character) -> String {
    let mutableText = NSMutableString(string: String(character))
    CFStringTransform(mutableText, nil, kCFStringTransformToLatin, false)
    CFStringTransform(mutableText, nil, kCFStringTransformStripCombiningMarks, false)

    return (mutableText as String)
        .first(where: { $0.isLetter || $0.isNumber })
        .map { String($0).lowercased() } ?? ""
}

private extension Character {
    var isHan: Bool {
        unicodeScalars.contains { value in
            (0x4E00...0x9FFF).contains(value.value)
                || (0x3400...0x4DBF).contains(value.value)
                || (0x20000...0x2A6DF).contains(value.value)
        }
    }
}
