import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
extension CottageState {
    func windowSwitcherCottageAction() -> CottageAction {
        let customAction = windowSwitcherCustomAction()
        return CottageAction(
            id: "built-in.windowSwitcher",
            title: L10n.text("action.windowSwitcher.title"),
            subtitle: L10n.text("action.windowSwitcher.subtitle"),
            symbolName: "rectangle.on.rectangle",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: ["window", "switcher", "app", L10n.text("tag.windowSwitcher")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }

    var isBuiltInWindowSwitcherPanelActive: Bool {
        activeCustomAction?.definition.id == Self.windowSwitcherActionID
    }

    func refreshBuiltInWindowSwitcherResults() {
        guard isBuiltInWindowSwitcherPanelActive else {
            return
        }

        let previousSelectedID = selectedCustomResultID
        let results = windowSwitcherResults(query: customQuery)
        customResults = results
        selectedCustomResultID = results.contains { $0.id == previousSelectedID }
            ? previousSelectedID
            : results.first?.id
        shownCustomResultMenuID = nil
        customResultIndex = results.count
        isCustomActionRunning = false
    }

    func runBuiltInWindowSwitcherResultIfNeeded(_ result: CustomActionResult) -> Bool {
        guard isBuiltInWindowSwitcherPanelActive,
              let command = result.command,
              let window = WindowSwitcherCommand(command) else {
            return false
        }

        activateWindow(window)
        showStatus(L10n.text("status.opened"))
        hideWindow()
        return true
    }
}

private extension CottageState {
    static let windowSwitcherActionID = "built-in-window-switcher"

    func windowSwitcherCustomAction() -> CustomAction {
        let definition = CustomActionDefinition(
            id: Self.windowSwitcherActionID,
            title: L10n.text("action.windowSwitcher.title"),
            subtitle: L10n.text("action.windowSwitcher.subtitle"),
            placeholder: L10n.text("action.windowSwitcher.placeholder"),
            symbolName: "rectangle.on.rectangle",
            tags: ["window", "switcher", "app", L10n.text("tag.windowSwitcher")],
            type: .script,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.windowSwitcher.placeholder"),
                debounceMilliseconds: 0,
                allowsEmptyQuery: true
            )
        )
        return CustomAction(definition: definition, directoryURL: FileManager.default.homeDirectoryForCurrentUser)
    }

    func windowSwitcherResults(query: String) -> [CustomActionResult] {
        let windows = currentWindowItems()
        let trimmedQuery = query.trimmedSearchText
        guard !trimmedQuery.isEmpty else {
            return windows.map(\.result)
        }

        let initials = normalizedSearchText(trimmedQuery)
        return windows
            .filter { $0.matches(trimmedQuery, initials: initials) }
            .map(\.result)
    }

    func currentWindowItems() -> [WindowSwitcherItem] {
        let yabaiItems = yabaiWindowItems()
        if !yabaiItems.isEmpty {
            return yabaiItems
        }

        let accessibilityItems = accessibilityWindowItems()
        let knownKeys = Set(accessibilityItems.map(\.deduplicationKey))
        guard let windowInfos = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return accessibilityItems
        }

        let fallbackItems = windowInfos
            .compactMap(windowSwitcherItem)
            .filter { !knownKeys.contains($0.deduplicationKey) }
        return accessibilityItems + fallbackItems
    }

    func yabaiWindowItems() -> [WindowSwitcherItem] {
        guard let yabaiURL = yabaiExecutableURL() else {
            return []
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = yabaiURL
        process.arguments = ["-m", "query", "--windows"]
        process.standardOutput = outputPipe
        do {
            try process.run()
        } catch {
            return []
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return []
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let windows = try? JSONDecoder().decode([YabaiWindow].self, from: data) else {
            return []
        }

        return windows.compactMap(\.windowSwitcherItem)
    }

    func yabaiExecutableURL() -> URL? {
        [
            "/opt/homebrew/bin/yabai",
            "/usr/local/bin/yabai",
            "/usr/bin/yabai"
        ]
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func accessibilityWindowItems() -> [WindowSwitcherItem] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .flatMap(accessibilityWindowItems)
    }

    func accessibilityWindowItems(for app: NSRunningApplication) -> [WindowSwitcherItem] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }

        return windows.enumerated().compactMap { index, window in
            accessibilityWindowItem(window, app: app, index: UInt32(index))
        }
    }

    func accessibilityWindowItem(
        _ window: AXUIElement,
        app: NSRunningApplication,
        index: UInt32
    ) -> WindowSwitcherItem? {
        guard let title = accessibilityString(window, attribute: kAXTitleAttribute),
              !title.trimmedSearchText.isEmpty else {
            return nil
        }

        let appName = app.localizedName ?? "Application"
        return WindowSwitcherItem(
            windowID: Int(UInt32(bitPattern: app.processIdentifier) &+ index),
            pid: app.processIdentifier,
            title: title,
            appName: appName,
            space: nil,
            source: .accessibility
        )
    }

    func accessibilityString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    func windowSwitcherItem(_ info: [String: Any]) -> WindowSwitcherItem? {
        guard let appName = info[kCGWindowOwnerName as String] as? String,
              let pid = numberValue(info[kCGWindowOwnerPID as String])?.int32Value,
              let windowID = numberValue(info[kCGWindowNumber as String])?.uint32Value,
              isRegularApplication(pid: pid),
              isNormalWindow(info) else {
            return nil
        }

        let title = info[kCGWindowName as String] as? String
        let visibleTitle = title?.trimmedSearchText.isEmpty == false ? title ?? appName : "\(appName) Window"
        return WindowSwitcherItem(
            windowID: Int(windowID),
            pid: pid,
            title: visibleTitle,
            appName: appName,
            space: nil,
            source: .coreGraphics
        )
    }

    func isRegularApplication(pid: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
    }

    func isNormalWindow(_ info: [String: Any]) -> Bool {
        let layer = numberValue(info[kCGWindowLayer as String])?.intValue ?? 0
        guard layer == 0 else {
            return false
        }

        if let alpha = numberValue(info[kCGWindowAlpha as String])?.doubleValue, alpha <= 0 {
            return false
        }

        return true
    }

    func numberValue(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber {
            return number
        }

        return nil
    }

    func activateWindow(_ window: WindowSwitcherCommand) {
        if let yabaiWindowID = window.yabaiWindowID,
           focusYabaiWindow(yabaiWindowID) {
            return
        }

        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        raiseWindowWithAppleScript(window)
    }

    func focusYabaiWindow(_ windowID: Int) -> Bool {
        guard let yabaiURL = yabaiExecutableURL() else {
            return false
        }

        let process = Process()
        process.executableURL = yabaiURL
        process.arguments = ["-m", "window", "--focus", "\(windowID)"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func raiseWindowWithAppleScript(_ window: WindowSwitcherCommand) {
        let script = """
        tell application "System Events"
            set targetProcesses to every process whose unix id is \(window.pid)
            if targetProcesses is not {} then
                tell item 1 of targetProcesses
                    set frontmost to true
                    try
                        perform action "AXRaise" of (first window whose name is \(appleScriptString(window.title)))
                    end try
                end tell
            end if
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    func appleScriptString(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

struct WindowSwitcherItem {
    let windowID: Int
    let pid: pid_t
    let title: String
    let appName: String
    let space: Int?
    let source: WindowSwitcherSource

    var deduplicationKey: String {
        "\(pid):\(title)"
    }

    var result: CustomActionResult {
        CustomActionResult(
            id: "window.\(windowID)",
            title: title,
            subtitle: appName,
            text: title,
            tags: ["window", appName, title],
            url: nil,
            path: nil,
            previewImagePath: nil,
            command: command,
            presentation: nil,
            navigationCommand: nil,
            navigation: nil,
            accessories: [
                CustomResultAccessory(text: appName, symbolName: "app", style: "secondary"),
                spaceAccessory
            ],
            metadata: [
                CustomResultMetadata(label: "PID", value: "\(pid)", type: "code", url: nil),
                CustomResultMetadata(label: "Window ID", value: "\(windowID)", type: "code", url: nil),
                CustomResultMetadata(label: "Source", value: source.rawValue, type: "text", url: nil)
            ],
            isError: false
        )
    }

    private var command: String {
        switch source {
        case .yabai:
            "cottage-window-switcher:yabai:\(windowID):\(pid):\(title)"
        case .accessibility, .coreGraphics:
            "cottage-window-switcher:native:\(windowID):\(pid):\(title)"
        }
    }

    private var spaceAccessory: CustomResultAccessory {
        if let space {
            return CustomResultAccessory(text: "Space \(space)", symbolName: "rectangle.3.group", style: "blue")
        }

        return CustomResultAccessory(text: source.rawValue, symbolName: "window.ceiling", style: "secondary")
    }

    func matches(_ query: String, initials: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || appName.localizedCaseInsensitiveContains(query)
            || (!initials.isEmpty && searchInitials(from: title).hasPrefix(initials))
            || (!initials.isEmpty && searchInitials(from: appName).hasPrefix(initials))
    }
}

private struct WindowSwitcherCommand {
    let yabaiWindowID: Int?
    let pid: pid_t
    let title: String

    init?(_ command: String) {
        let parts = command.split(separator: ":", maxSplits: 4).map(String.init)
        guard parts.count == 5,
              parts[0] == "cottage-window-switcher",
              let windowID = Int(parts[2]),
              let pid = Int32(parts[3]) else {
            return nil
        }

        yabaiWindowID = parts[1] == "yabai" ? windowID : nil
        self.pid = pid
        title = parts[4]
    }
}

enum WindowSwitcherSource: String {
    case yabai
    case accessibility
    case coreGraphics
}
