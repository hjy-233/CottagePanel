// 保存 action panel 最近输入和结果缓存
import Foundation

struct CustomPanelCache {
    let query: String
    let results: [CustomActionResult]
    let selectedResultID: String?
    let savedAt: Date
}
