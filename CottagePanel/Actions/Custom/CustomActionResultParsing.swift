import Foundation

private struct CustomActionResultPayload: Decodable {
    let id: String?
    let title: String?
    let subtitle: String?
    let text: String?
    let tags: [String]?
    let url: String?
    let path: String?
    let previewImagePath: String?
    let command: String?
    let presentation: CustomActionPresentation?
    let navigationCommand: String?
    let navigation: CustomResultNavigationDefinition?
    let accessories: [CustomResultAccessory]?
    let metadata: [CustomResultMetadata]?
}

func customActionResult(from jsonLine: String, fallbackID: String) -> CustomActionResult {
    guard let data = jsonLine.data(using: .utf8),
          let payload = try? JSONDecoder().decode(CustomActionResultPayload.self, from: data) else {
        return CustomActionResult(
            id: "error.\(fallbackID)",
            title: L10n.text("custom.result.invalidJSON"),
            subtitle: jsonLine,
            text: jsonLine,
            tags: [],
            url: nil,
            path: nil,
            previewImagePath: nil,
            command: nil,
            presentation: nil,
            navigationCommand: nil,
            navigation: nil,
            accessories: [],
            metadata: [],
            isError: true
        )
    }

    let text = payload.text ?? payload.subtitle ?? payload.title ?? ""
    return CustomActionResult(
        id: payload.id ?? fallbackID,
        title: payload.title ?? text,
        subtitle: payload.subtitle ?? "",
        text: text,
        tags: payload.tags ?? [],
        url: payload.url,
        path: payload.path,
        previewImagePath: payload.previewImagePath,
        command: payload.command,
        presentation: payload.presentation,
        navigationCommand: payload.navigationCommand,
        navigation: payload.navigation,
        accessories: payload.accessories ?? [],
        metadata: payload.metadata ?? [],
        isError: false
    )
}
