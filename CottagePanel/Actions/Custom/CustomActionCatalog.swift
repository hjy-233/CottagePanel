import AppKit
import Foundation

extension CottageState {
    func customActions() -> [CottageAction] {
        ensureActionsDirectory()

        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: actionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return directories.compactMap(customAction)
    }

    func openActionsDirectory() {
        ensureActionsDirectory()
        NSWorkspace.shared.open(actionsDirectory)
    }

    private func customAction(from directoryURL: URL) -> CottageAction? {
        guard isDirectory(directoryURL) else {
            return nil
        }

        let jsonURL = directoryURL.appendingPathComponent("action.json")
        guard let data = try? Data(contentsOf: jsonURL) else {
            return nil
        }

        do {
            let definition = try JSONDecoder().decode(CustomActionDefinition.self, from: data)
            guard !builtInCustomActionIDs.contains(definition.id) else {
                return nil
            }
            guard validate(definition, in: jsonURL) else {
                return nil
            }

            let customAction = CustomAction(definition: definition, directoryURL: directoryURL)
            return CottageAction(
                id: customAction.actionID,
                title: definition.title,
                subtitle: definition.subtitle,
                symbolName: customAction.symbolName,
                kind: .command,
                icon: customAction.icon,
                fileURL: directoryURL,
                customAction: customAction,
                tags: definition.tags + ["custom", definition.type.rawValue]
            ) { [weak self] in
                self?.runCustomAction(customAction)
            }
        } catch {
            NSLog("CottagePanel cannot parse \(jsonURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    private var actionsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
            .appendingPathComponent("actions", isDirectory: true)
    }

    private func ensureActionsDirectory() {
        guard !FileManager.default.fileExists(atPath: actionsDirectory.path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: actionsDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("CottagePanel cannot create actions directory: \(error.localizedDescription)")
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func validate(_ definition: CustomActionDefinition, in url: URL) -> Bool {
        let isValid = validateRequiredFields(definition)
            && validateIDs(definition)
            && validateAccessory(definition)
            && validateForm(definition)
            && validateMenus(definition)

        if !isValid {
            NSLog("CottagePanel custom action invalid: \(url.path)")
        }

        return isValid
    }

    private var builtInCustomActionIDs: Set<String> {
        [
            "calculate",
            "built-in-calculate",
            "built-in-file-search",
            "built-in-translator",
            "built-in-color-converter",
            "built-in-unix-time-converter",
            "built-in-json-formatter",
            "built-in-git-viewer",
            "built-in-words-count",
            "built-in-hash",
            "built-in-web-search",
            "built-in-process-manager",
            "built-in-qr-code",
            "unix-time-converter",
            "json-formatter",
            "git-viewer",
            "words-count",
            "hash",
            "web-search",
            "process-manager",
            "qr-code",
            "color-converter",
            "translator"
        ]
    }

    private func validateRequiredFields(_ definition: CustomActionDefinition) -> Bool {
        guard definition.apiVersion == 1 else {
            return false
        }

        return switch definition.type {
        case .script, .shell:
            definition.command?.isEmpty == false
        case .open, .openApp:
            definition.path?.isEmpty == false
        case .url:
            definition.url?.isEmpty == false
        case .shortcut:
            definition.shortcutName?.isEmpty == false
        }
    }

    private func validateIDs(_ definition: CustomActionDefinition) -> Bool {
        validateID(definition.id)
            && definition.tags.allSatisfy(validateLooseID)
    }

    private func validateAccessory(_ definition: CustomActionDefinition) -> Bool {
        guard let accessory = definition.searchAccessory else {
            return true
        }

        let itemIDs = Set(accessory.items.map(\.id))
        return validateID(accessory.id)
            && accessory.items.allSatisfy { validateID($0.id) }
            && itemIDs.count == accessory.items.count
            && itemIDs.contains(accessory.defaultValue)
    }

    private func validateForm(_ definition: CustomActionDefinition) -> Bool {
        guard let fields = definition.form?.fields else {
            return true
        }

        let ids = fields.map(\.id)
        let envKeys = ids.map(normalizedEnvironmentKey)
        return Set(ids).count == ids.count
            && Set(envKeys).count == envKeys.count
            && fields.allSatisfy(validateFormField)
    }

    private func validateFormField(_ field: CustomFormFieldDefinition) -> Bool {
        let defaultIsValid = field.defaultValue.map { value in
            field.items.isEmpty || field.items.contains { $0.id == value }
        } ?? true
        return validateID(field.id)
            && field.items.allSatisfy { validateID($0.id) }
            && Set(field.items.map(\.id)).count == field.items.count
            && defaultIsValid
    }

    private func validateMenus(_ definition: CustomActionDefinition) -> Bool {
        validateMenuActions(definition.actionMenuActions, depth: 0)
            && validateResultActions(definition.resultActions, depth: 0)
    }

    private func validateMenuActions(_ actions: [CustomMenuActionDefinition], depth: Int) -> Bool {
        guard depth <= 5 else {
            return false
        }

        return actions.allSatisfy { action in
            validateID(action.id) && validateMenuActions(action.children, depth: depth + 1)
        }
    }

    private func validateResultActions(_ actions: [CustomResultActionDefinition], depth: Int) -> Bool {
        guard depth <= 5 else {
            return false
        }

        return actions.allSatisfy { action in
            validateID(action.id) && validateResultActions(action.children, depth: depth + 1)
        }
    }

    private func validateID(_ text: String) -> Bool {
        !text.isEmpty && text.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }

    private func validateLooseID(_ text: String) -> Bool {
        !text.isEmpty
    }
}
