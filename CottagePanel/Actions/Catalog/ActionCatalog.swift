import AppKit

@MainActor
extension CottageState {
    var builtInActions: [CottageAction] {
        [
            settingsCottageAction(),
            CottageAction(
                id: "built-in.config",
                title: L10n.text("action.config.title"),
                subtitle: "~/.config/cottage/",
                symbolName: "folder.badge.gearshape",
                kind: .finderItem,
                icon: icon(forHomePath: ".config/cottage"),
                fileURL: configURL(),
                tags: ["config", "cottage", L10n.text("tag.config")]
            ) { [weak self] in
                self?.openConfig()
            },
            recentSearchCottageAction(),
            calculateCottageAction(),
            translatorCottageAction(),
            colorConverterCottageAction(),
            unixTimeConverterCottageAction(),
            jsonFormatterCottageAction(),
            gitViewerCottageAction(),
            wordsCountCottageAction(),
            hashCottageAction(),
            webSearchCottageAction(),
            processManagerCottageAction(),
            windowSwitcherCottageAction(),
            qrCodeCottageAction(),
            fileSearchCottageAction(),
            CottageAction(
                id: "built-in.reloadActions",
                title: L10n.text("action.reloadActions.title"),
                subtitle: L10n.text("action.reloadActions.subtitle"),
                symbolName: "arrow.clockwise",
                kind: .command,
                icon: nil,
                tags: ["reload", "actions", "refresh"]
            ) { [weak self] in
                self?.reloadActionsFromUserAction()
            }
        ]
    }
}

private func icon(forHomePath path: String) -> NSImage {
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
    return icon(for: url.path)
}

private func configURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config", isDirectory: true)
        .appendingPathComponent("cottage", isDirectory: true)
}

private func icon(for path: String) -> NSImage {
    NSWorkspace.shared.icon(forFile: path)
}
