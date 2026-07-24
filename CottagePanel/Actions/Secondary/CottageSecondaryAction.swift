import AppKit

struct CottageSecondaryAction: Identifiable {
    let id: String
    let title: String
    let shortcut: String
    let symbolName: String
    let dismissesPalette: Bool
    let isDestructive: Bool
    let run: @MainActor (CottageAction) -> Void

    init(
        id: String,
        title: String,
        shortcut: String,
        symbolName: String,
        dismissesPalette: Bool = true,
        isDestructive: Bool = false,
        run: @escaping @MainActor (CottageAction) -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.symbolName = symbolName
        self.dismissesPalette = dismissesPalette
        self.isDestructive = isDestructive
        self.run = run
    }
}

func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

func terminateApplications(for action: CottageAction, force: Bool) {
    guard let bundleIdentifier = action.bundleIdentifier else {
        return
    }

    NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).forEach { application in
        if force {
            application.forceTerminate()
        } else {
            application.terminate()
        }
    }
}

func uninstallApplication(_ action: CottageAction, fileURL: URL) {
    let alert = NSAlert()
    alert.messageText = L10n.text("uninstall.title")
    alert.informativeText = action.title
    alert.addButton(withTitle: L10n.text("uninstall.appOnly"))
    alert.addButton(withTitle: L10n.text("uninstall.withData"))
    alert.addButton(withTitle: L10n.text("uninstall.cancel"))

    switch alert.runModal() {
    case .alertFirstButtonReturn:
        moveToTrash(fileURL)
    case .alertSecondButtonReturn:
        moveToTrash(fileURL)
        removeApplicationData(for: action)
    default:
        break
    }
}

private func moveToTrash(_ url: URL) {
    do {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    } catch {
        NSLog("CottagePanel cannot move item to trash: \(error.localizedDescription)")
    }
}

private func removeApplicationData(for action: CottageAction) {
    guard let bundleIdentifier = action.bundleIdentifier else {
        return
    }

    applicationDataURLs(for: action.title, bundleIdentifier: bundleIdentifier).forEach { url in
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        moveToTrash(url)
    }
}

private func applicationDataURLs(for title: String, bundleIdentifier: String) -> [URL] {
    let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")

    return [
        library.appendingPathComponent("Application Support").appendingPathComponent(title),
        library.appendingPathComponent("Caches").appendingPathComponent(bundleIdentifier),
        library.appendingPathComponent("Preferences").appendingPathComponent("\(bundleIdentifier).plist"),
        library
            .appendingPathComponent("Saved Application State")
            .appendingPathComponent("\(bundleIdentifier).savedState")
    ]
}
