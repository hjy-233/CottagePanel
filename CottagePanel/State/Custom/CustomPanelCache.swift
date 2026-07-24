import Foundation

struct CustomPanelCache {
    let query: String
    let results: [CustomActionResult]
    let selectedResultID: String?
    let savedAt: Date
}
