import AppKit
import Foundation
import UniformTypeIdentifiers

extension CottageState {
    func reloadActionsFromUserAction() {
        closeCustomPopup()
        if activeCustomAction != nil {
            leaveCustomPanel()
        } else {
            stopCustomProcess()
        }
        reloadActions()
        selectedActionID = filteredActions.first?.id
        showStatus(String(format: L10n.text("status.actionsReloaded"), customActions().count))
        focusSearch()
    }

    func importActionsArchive() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip, .folder]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = L10n.text("actions.import.message")

        guard panel.runModal() == .OK, let url = panel.url else {
            focusSearch()
            return
        }

        do {
            let result = try importActions(from: url)
            reloadActions()
            selectedActionID = filteredActions.first?.id
            showStatus(
                String(
                    format: L10n.text("status.actionsImported"),
                    result.imported,
                    result.updated,
                    result.skipped
                )
            )
        } catch {
            showStatus(L10n.text("status.actionsImportFailed"))
            NSLog("CottagePanel cannot import actions: \(error.localizedDescription)")
        }
        focusSearch()
    }

    func exportActionsArchive() {
        exportActionItems = availableActionFolders().map { folder in
            ActionExportItem(folder: folder, isSelected: true)
        }
        guard !exportActionItems.isEmpty else {
            showStatus(L10n.text("status.noActionsToExport"))
            focusSearch()
            return
        }

        if isBuiltInSettingsPanelActive {
            enterBuiltInSettingsExportPanel()
            return
        }

        showsActionExportSheet = true
        focusSearch()
    }

    func confirmActionsExport() {
        let selectedFolders = exportActionItems
            .filter(\.isSelected)
            .map(\.folder)
        guard !selectedFolders.isEmpty else {
            showStatus(L10n.text("status.noActionsToExport"))
            focusSearch()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.nameFieldStringValue = "cottage-actions.zip"
        savePanel.message = L10n.text("actions.export.message")

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            focusSearch()
            return
        }

        do {
            try exportActionFolders(selectedFolders, to: destinationURL)
            showStatus(String(format: L10n.text("status.actionsExported"), selectedFolders.count))
            showsActionExportSheet = false
            if isBuiltInSettingsExportPanelActive {
                _ = popCustomNavigationStack()
            }
        } catch {
            showStatus(L10n.text("status.actionsExportFailed"))
            NSLog("CottagePanel cannot export actions: \(error.localizedDescription)")
        }
        focusSearch()
    }
}

private extension CottageState {
    var archiveActionsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
            .appendingPathComponent("actions", isDirectory: true)
    }

    func availableActionFolders() -> [ActionFolder] {
        ensureArchiveActionsDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: archiveActionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { isDirectory($0) }
            .map { ActionFolder(url: $0, title: actionTitle(in: $0) ?? $0.lastPathComponent) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func actionTitle(in folder: URL) -> String? {
        let jsonURL = folder.appendingPathComponent("action.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object["title"] as? String
    }

    func importActions(from url: URL) throws -> ActionImportResult {
        ensureArchiveActionsDirectory()
        let sourceURL = try preparedImportSource(url)
        defer {
            if sourceURL.path.contains(FileManager.default.temporaryDirectory.path) {
                try? FileManager.default.removeItem(at: sourceURL)
            }
        }

        let existingFolders = availableActionFolders()
        let sourceFolders = try candidateActionFolders(in: sourceURL)
        var imported = 0
        var updated = 0
        var skipped = 0

        for folder in sourceFolders {
            if let existingFolder = conflictingExistingFolder(for: folder, in: existingFolders) {
                switch importConflictResolution(source: folder, existing: existingFolder.url) {
                case .keepCurrent:
                    skipped += 1
                case .update:
                    try replaceActionFolder(existingFolder.url, with: folder)
                    updated += 1
                }
            } else {
                let destination = archiveActionsDirectory
                    .appendingPathComponent(folder.lastPathComponent, isDirectory: true)
                try copyImportedActionFolder(from: folder, to: destination)
                imported += 1
            }
        }

        return ActionImportResult(imported: imported, updated: updated, skipped: skipped)
    }

    func conflictingExistingFolder(for folder: URL, in existingFolders: [ActionFolder]) -> ActionFolder? {
        let id = actionID(folder)
        if let nameConflict = existingFolders.first(where: { existingFolder in
            existingFolder.url.lastPathComponent == folder.lastPathComponent
        }) {
            return nameConflict
        }

        return existingFolders.first { existingFolder in
            id.map { actionID(existingFolder) == $0 } == true
        }
    }

    func importConflictResolution(source: URL, existing: URL) -> ActionImportConflictResolution {
        let alert = NSAlert()
        alert.messageText = L10n.text("actions.import.conflict.title")
        alert.informativeText = String(
            format: L10n.text("actions.import.conflict.message"),
            actionTitle(in: existing) ?? existing.lastPathComponent,
            existing.path,
            source.path
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("actions.import.conflict.update"))
        alert.addButton(withTitle: L10n.text("actions.import.conflict.keep"))

        return alert.runModal() == .alertFirstButtonReturn ? .update : .keepCurrent
    }

    func replaceActionFolder(_ existing: URL, with source: URL) throws {
        let destination = archiveActionsDirectory
            .appendingPathComponent(source.lastPathComponent, isDirectory: true)
        let backup = FileManager.default.temporaryDirectory
            .appendingPathComponent("cottage-action-backup-\(UUID().uuidString)", isDirectory: true)

        guard existing == destination || !FileManager.default.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.moveItem(at: existing, to: backup)
        do {
            try copyImportedActionFolder(from: source, to: destination)
            try? FileManager.default.removeItem(at: backup)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.moveItem(at: backup, to: existing)
            throw error
        }
    }

    func copyImportedActionFolder(from source: URL, to destination: URL) throws {
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try validateImportedActionFolder(destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func validateImportedActionFolder(_ folder: URL) throws {
        guard isDirectory(folder),
              actionID(folder) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func preparedImportSource(_ url: URL) throws -> URL {
        if isDirectory(url) {
            return url
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("cottage-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", url.path, destination.path])
        return destination
    }

    func candidateActionFolders(in sourceURL: URL) throws -> [URL] {
        let directFolders = try FileManager.default.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { isDirectory($0) && hasActionJSON($0) }

        if !directFolders.isEmpty {
            return directFolders
        }

        return try FileManager.default.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { isDirectory($0) }
        .flatMap { try candidateActionFolders(in: $0) }
    }

    func exportActionFolders(_ folders: [ActionFolder], to destinationURL: URL) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cottage-export-\(UUID().uuidString)", isDirectory: true)
        let stagingURL = tempURL.appendingPathComponent("actions", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        for folder in folders {
            let destination = stagingURL.appendingPathComponent(folder.url.lastPathComponent, isDirectory: true)
            try FileManager.default.copyItem(at: folder.url, to: destination)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try runProcess(
            "/usr/bin/ditto",
            arguments: ["-c", "-k", "--keepParent", stagingURL.path, destinationURL.path]
        )
    }

    func actionID(_ folder: ActionFolder) -> String? {
        actionID(folder.url)
    }

    func actionID(_ folderURL: URL) -> String? {
        let jsonURL = folderURL.appendingPathComponent("action.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object["id"] as? String
    }

    func hasActionJSON(_ folderURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: folderURL.appendingPathComponent("action.json").path)
    }

    func ensureArchiveActionsDirectory() {
        guard !FileManager.default.fileExists(atPath: archiveActionsDirectory.path) else {
            return
        }

        try? FileManager.default.createDirectory(at: archiveActionsDirectory, withIntermediateDirectories: true)
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

private struct ActionImportResult {
    let imported: Int
    let updated: Int
    let skipped: Int
}

private enum ActionImportConflictResolution {
    case keepCurrent
    case update
}

struct ActionExportItem: Identifiable {
    let id = UUID()
    let folder: ActionFolder
    var isSelected: Bool
}

struct ActionFolder: Hashable {
    let url: URL
    let title: String
}
