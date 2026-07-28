// 提供搜索字符串归一化和首字母匹配辅助
import Foundation

extension String {
    var trimmedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
