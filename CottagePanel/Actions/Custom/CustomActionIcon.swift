// 加载自定义 action 目录内的图标资源
import AppKit
import Foundation

extension CustomAction {
    var icon: NSImage? {
        guard let iconPath = definition.icon else {
            return nil
        }

        guard let iconURL = containedFileURL(relativePath: iconPath) else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }
}
