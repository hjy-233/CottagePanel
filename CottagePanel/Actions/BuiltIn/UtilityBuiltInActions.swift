import AppKit
import Foundation

@MainActor
extension CottageState {
    func unixTimeConverterCottageAction() -> CottageAction {
        utilityCottageAction(UtilityBuiltInActionSpec(
            id: "built-in.unixTimeConverter",
            customAction: unixTimeConverterCustomAction(),
            titleKey: "action.unixTimeConverter.title",
            subtitleKey: "action.unixTimeConverter.subtitle",
            symbolName: "clock",
            tags: ["unix", "time", "timestamp", "date", "时间", L10n.text("tag.unixTimeConverter")]
        ))
    }

    func jsonFormatterCottageAction() -> CottageAction {
        utilityCottageAction(UtilityBuiltInActionSpec(
            id: "built-in.jsonFormatter",
            customAction: jsonFormatterCustomAction(),
            titleKey: "action.jsonFormatter.title",
            subtitleKey: "action.jsonFormatter.subtitle",
            symbolName: "curlybraces",
            tags: ["json", "formatter", "format", "validate", L10n.text("tag.jsonFormatter")]
        ))
    }

    func gitViewerCottageAction() -> CottageAction {
        utilityCottageAction(UtilityBuiltInActionSpec(
            id: "built-in.gitViewer",
            customAction: gitViewerCustomAction(),
            titleKey: "action.gitViewer.title",
            subtitleKey: "action.gitViewer.subtitle",
            symbolName: "point.3.connected.trianglepath.dotted",
            tags: ["git", "repo", "status", "branch", "commit", L10n.text("tag.gitViewer")]
        ))
    }

    func wordsCountCottageAction() -> CottageAction {
        utilityCottageAction(UtilityBuiltInActionSpec(
            id: "built-in.wordsCount",
            customAction: wordsCountCustomAction(),
            titleKey: "action.wordsCount.title",
            subtitleKey: "action.wordsCount.subtitle",
            symbolName: "textformat.abc",
            tags: ["words", "count", "text", "统计", "字数", L10n.text("tag.wordsCount")]
        ))
    }

    func hashCottageAction() -> CottageAction {
        utilityCottageAction(UtilityBuiltInActionSpec(
            id: "built-in.hash",
            customAction: hashCustomAction(),
            titleKey: "action.hash.title",
            subtitleKey: "action.hash.subtitle",
            symbolName: "number",
            tags: ["hash", "md5", "sha", "file", "text", "哈希", L10n.text("tag.hash")]
        ))
    }

    private func utilityCottageAction(_ spec: UtilityBuiltInActionSpec) -> CottageAction {
        CottageAction(
            id: spec.id,
            title: L10n.text(spec.titleKey),
            subtitle: L10n.text(spec.subtitleKey),
            symbolName: spec.symbolName,
            kind: .command,
            icon: nil,
            fileURL: spec.customAction.directoryURL,
            customAction: spec.customAction,
            tags: spec.tags
        ) { [weak self] in
            self?.runCustomAction(spec.customAction)
        }
    }
}

private struct UtilityBuiltInActionSpec {
    let id: String
    let customAction: CustomAction
    let titleKey: String
    let subtitleKey: String
    let symbolName: String
    let tags: [String]
}

private func unixTimeConverterCustomAction() -> CustomAction {
    scriptCustomAction(UtilityScriptActionSpec(
        id: "built-in-unix-time-converter",
        titleKey: "action.unixTimeConverter.title",
        subtitleKey: "action.unixTimeConverter.subtitle",
        placeholderKey: "action.unixTimeConverter.placeholder",
        symbolName: "clock",
        tags: ["unix", "time", "timestamp", "date", "时间", L10n.text("tag.unixTimeConverter")],
        scriptFolder: "UnixTimeConverter",
        scriptName: "unix-time-converter-run.py",
        trigger: .live
    ))
}

private func jsonFormatterCustomAction() -> CustomAction {
    scriptCustomAction(UtilityScriptActionSpec(
        id: "built-in-json-formatter",
        titleKey: "action.jsonFormatter.title",
        subtitleKey: "action.jsonFormatter.subtitle",
        placeholderKey: "action.jsonFormatter.placeholder",
        symbolName: "curlybraces",
        tags: ["json", "formatter", "format", "validate", L10n.text("tag.jsonFormatter")],
        scriptFolder: "JSONFormatter",
        scriptName: "json-formatter-run.py",
        trigger: .live,
        preview: CustomActionPreviewDefinition(style: .json)
    ))
}

private func gitViewerCustomAction() -> CustomAction {
    scriptCustomAction(UtilityScriptActionSpec(
        id: "built-in-git-viewer",
        titleKey: "action.gitViewer.title",
        subtitleKey: "action.gitViewer.subtitle",
        placeholderKey: "action.gitViewer.placeholder",
        symbolName: "point.3.connected.trianglepath.dotted",
        tags: ["git", "repo", "status", "branch", "commit", L10n.text("tag.gitViewer")],
        scriptFolder: "GitViewer",
        scriptName: "git-viewer-run.py",
        trigger: .manual
    ))
}

private func wordsCountCustomAction() -> CustomAction {
    scriptCustomAction(UtilityScriptActionSpec(
        id: "built-in-words-count",
        titleKey: "action.wordsCount.title",
        subtitleKey: "action.wordsCount.subtitle",
        placeholderKey: "action.wordsCount.placeholder",
        symbolName: "textformat.abc",
        tags: ["words", "count", "text", "统计", "字数", L10n.text("tag.wordsCount")],
        scriptFolder: "WordsCount",
        scriptName: "words-count-run.py",
        trigger: .live
    ))
}

private func hashCustomAction() -> CustomAction {
    scriptCustomAction(UtilityScriptActionSpec(
        id: "built-in-hash",
        titleKey: "action.hash.title",
        subtitleKey: "action.hash.subtitle",
        placeholderKey: "action.hash.placeholder",
        symbolName: "number",
        tags: ["hash", "md5", "sha", "file", "text", "哈希", L10n.text("tag.hash")],
        scriptFolder: "Hash",
        scriptName: "hash-run.py",
        trigger: .live,
        menuActions: [pickFileSHA256MenuAction()]
    ))
}

private struct UtilityScriptActionSpec {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let placeholderKey: String
    let symbolName: String
    let tags: [String]
    let scriptFolder: String
    let scriptName: String
    let trigger: CustomActionTrigger
    var menuActions: [CustomMenuActionDefinition] = []
    var preview: CustomActionPreviewDefinition = CustomActionPreviewDefinition(style: .text)
}

private func scriptCustomAction(_ spec: UtilityScriptActionSpec) -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: spec.id,
            title: L10n.text(spec.titleKey),
            subtitle: L10n.text(spec.subtitleKey),
            placeholder: L10n.text(spec.placeholderKey),
            symbolName: spec.symbolName,
            tags: spec.tags,
            type: .script,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: spec.trigger,
            menuActions: spec.menuActions,
            preview: spec.preview,
            input: CustomActionInputDefinition(
                placeholder: L10n.text(spec.placeholderKey),
                debounceMilliseconds: 250,
                allowsEmptyQuery: false
            )
        ),
        directoryURL: utilityScriptDirectoryURL(spec.scriptFolder, scriptName: spec.scriptName)
    )
}

private func pickFileSHA256MenuAction() -> CustomMenuActionDefinition {
    CustomMenuActionDefinition(
        id: "pick-file-sha256",
        title: L10n.text("hash.pickFileSHA256"),
        symbolName: "doc.badge.gearshape",
        shortcut: "cmd+o",
        type: .shell,
        command: """
        file=$(/usr/bin/osascript -e 'POSIX path of (choose file)')
        /usr/bin/openssl dgst -sha256 -r "$file" | /usr/bin/awk '{print $1}' | /usr/bin/pbcopy
        """,
        path: nil,
        url: nil,
        shortcutName: nil
    )
}

private func utilityScriptDirectoryURL(_ folder: String, scriptName: String) -> URL {
    if let url = Bundle.main.url(
        forResource: scriptName.replacingOccurrences(of: ".py", with: ""),
        withExtension: "py"
    ) {
        return url.deletingLastPathComponent()
    }

    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent(folder)
}
