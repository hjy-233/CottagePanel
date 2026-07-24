import AppKit

enum CottageAppIcon {
    static func image(size: NSSize? = nil) -> NSImage {
        let image = bundledIcon() ?? NSApp.applicationIconImage.copy() as? NSImage ?? fallbackIcon()
        if let size {
            image.size = size
        }
        image.isTemplate = false
        return image
    }

    private static func bundledIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func fallbackIcon() -> NSImage {
        NSImage(systemSymbolName: "house", accessibilityDescription: "Cottage") ?? NSImage()
    }
}
