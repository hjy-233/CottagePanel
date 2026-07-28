// 定义传给 action stdin 的结构化输入 payload
import Foundation

struct CustomActionInputPayload: Encodable {
    let apiVersion: Int
    let query: String
    let form: [String: String]
    let accessory: [String: String]
    let result: CustomActionResultInputPayload?
    let navigation: CustomActionNavigationInputPayload?
}

struct CustomActionResultInputPayload: Encodable {
    let id: String
    let title: String
    let subtitle: String
    let text: String
    let url: String?
    let path: String?
    let previewImagePath: String?
    let command: String?

    init(_ result: CustomActionResult) {
        id = result.id
        title = result.title
        subtitle = result.subtitle
        text = result.text
        url = result.url
        path = result.path
        previewImagePath = result.previewImagePath
        command = result.command
    }
}

struct CustomActionNavigationInputPayload: Encodable {
    let sourceActionId: String
    let sourceResultId: String
    let depth: Int
}
