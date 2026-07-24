import Foundation

struct CustomPanelNavigationState: Hashable {
    let action: CustomAction
    let query: String
    let accessoryValue: String
    let formValues: [String: String]
    let results: [CustomActionResult]
    let selectedResultID: String?
    let resultIndex: Int
    let sourceResult: CustomActionResult?
}
