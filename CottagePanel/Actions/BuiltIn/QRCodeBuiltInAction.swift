import AppKit
import Foundation

@MainActor
extension CottageState {
    func qrCodeCottageAction() -> CottageAction {
        let customAction = qrCodeCustomAction()
        return CottageAction(
            id: "built-in.qrCode",
            title: L10n.text("action.qrCode.title"),
            subtitle: L10n.text("action.qrCode.subtitle"),
            symbolName: "qrcode",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: ["qr", "qrcode", "code", "image", "url", L10n.text("tag.qrCode")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func qrCodeCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-qr-code",
            title: L10n.text("action.qrCode.title"),
            subtitle: L10n.text("action.qrCode.subtitle"),
            placeholder: L10n.text("action.qrCode.placeholder"),
            symbolName: "qrcode",
            tags: ["qr", "qrcode", "code", "image", "url", L10n.text("tag.qrCode")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.qrCode.placeholder"),
                debounceMilliseconds: 40,
                allowsEmptyQuery: false
            ),
            searchAccessory: CustomSearchAccessoryDefinition(
                id: "type",
                envKey: "code_type",
                defaultValue: "qr",
                items: qrCodeTypes
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private let qrCodeTypes = [
    CustomPickerItemDefinition(id: "qr", title: "QR"),
    CustomPickerItemDefinition(id: "aztec", title: "Aztec"),
    CustomPickerItemDefinition(id: "pdf417", title: "PDF417")
]

private let qrCodeShellCommand = ""
