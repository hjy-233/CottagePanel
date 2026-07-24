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
