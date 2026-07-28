// 封装 action 文件、URL等操作
import AppKit
import Foundation

extension CustomActionRunner {
    @discardableResult
    static func openPath(_ path: String?) -> Bool {
        guard let path else {
            return false
        }

        let expandedPath = NSString(string: path).expandingTildeInPath
        return NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
    }

    @discardableResult
    static func revealPath(_ path: String?) -> Bool {
        guard let path else {
            return false
        }

        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }

    @discardableResult
    static func openURL(_ urlString: String?) -> Bool {
        guard let urlString, let url = URL(string: urlString) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}
