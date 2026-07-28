// swiftlint:disable blanket_disable_command file_length large_tuple line_length
// 实现二维码、颜色、网页搜索、翻译等媒体和网络内置逻辑
import AppKit
import CoreImage
import CryptoKit
import Foundation

enum NativeColorConverterBuiltIn {
    static func results(query: String) throws -> [CustomActionResult] {
        guard let color = NativeRGBAColor.parse(query) else {
            return [
                nativeResult(
                    id: "color-error",
                    title: "Invalid color",
                    subtitle: query,
                    text: "Try #ff6600, rgb(255, 102, 0), hsl(24, 100%, 50%), or orange.",
                    tags: ["error", "color"],
                    isError: true
                )
            ]
        }

        let hexRGB = String(format: "#%02X%02X%02X", color.red, color.green, color.blue)
        let hexRGBA = String(format: "%@%02X", hexRGB, color.alpha)
        let alpha = Double(color.alpha) / 255
        let rgb = "rgb(\(color.red), \(color.green), \(color.blue))"
        let rgba = String(format: "rgba(%d, %d, %d, %.3g)", color.red, color.green, color.blue, alpha)
        let hsl = color.hslText
        let swiftUI = String(
            format: "Color(red: %.3f, green: %.3f, blue: %.3f, opacity: %.3g)",
            Double(color.red) / 255,
            Double(color.green) / 255,
            Double(color.blue) / 255,
            alpha
        )
        let imageURL = try colorSwatchURL(color)
        let css = color.alpha == 255 ? hexRGB : hexRGBA
        return [
            nativeResult(
                id: "color-\(color.cacheKey)",
                title: css,
                subtitle: rgb,
                text: [hexRGB, hexRGBA, rgb, rgba, hsl, swiftUI].joined(separator: "\n"),
                tags: ["color", "hex", "rgb", "hsl"],
                previewImagePath: imageURL.path,
                accessories: [
                    CustomResultAccessory(text: "HEX", symbolName: "number", style: "blue"),
                    CustomResultAccessory(text: "RGB", symbolName: "circle.grid.cross", style: "green"),
                    CustomResultAccessory(text: "\(Int(round(alpha * 100)))%", symbolName: "circle.lefthalf.filled", style: "secondary")
                ],
                metadata: [
                    CustomResultMetadata(label: "HEX", value: hexRGB, type: "code", url: nil),
                    CustomResultMetadata(label: "HEX Alpha", value: hexRGBA, type: "code", url: nil),
                    CustomResultMetadata(label: "RGB", value: rgb, type: "code", url: nil),
                    CustomResultMetadata(label: "RGBA", value: rgba, type: "code", url: nil),
                    CustomResultMetadata(label: "HSL", value: hsl, type: "code", url: nil),
                    CustomResultMetadata(label: "SwiftUI", value: swiftUI, type: "code", url: nil)
                ]
            )
        ]
    }

    private static func colorSwatchURL(_ color: NativeRGBAColor) throws -> URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/cottage/colors", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(color.cacheKey).png")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let width = 420
        let height = 240
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let representation else {
            throw NativeBuiltInError.message("Cannot create color swatch")
        }

        for yPosition in 0..<height {
            for xPosition in 0..<width {
                let checker = ((xPosition / 24) + (yPosition / 24)).isMultiple(of: 2)
                let base = checker ? 238 : 210
                let ratio = Double(color.alpha) / 255
                representation.setColor(
                    NSColor(
                        calibratedRed: blend(color.red, base: base, ratio: ratio),
                        green: blend(color.green, base: base, ratio: ratio),
                        blue: blend(color.blue, base: base, ratio: ratio),
                        alpha: 1
                    ),
                    atX: xPosition,
                    y: yPosition
                )
            }
        }

        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw NativeBuiltInError.message("Cannot encode color swatch")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func blend(_ channel: Int, base: Int, ratio: Double) -> CGFloat {
        CGFloat((Double(channel) * ratio + Double(base) * (1 - ratio)) / 255)
    }
}

private struct NativeRGBAColor {
    let red: Int
    let green: Int
    let blue: Int
    let alpha: Int

    static func parse(_ text: String) -> NativeRGBAColor? {
        let trimmed = text.trimmedSearchText.lowercased()
        if let named = namedColors[trimmed] {
            return named
        }
        if let hex = parseHex(trimmed) {
            return hex
        }
        if let rgb = parseRGB(trimmed) {
            return rgb
        }
        if let hsl = parseHSL(trimmed) {
            return hsl
        }
        let parts = trimmed.split(separator: /[,\s]+/).map(String.init)
        guard parts.count == 3 || parts.count == 4,
              let red = parseChannel(parts[0]),
              let green = parseChannel(parts[1]),
              let blue = parseChannel(parts[2]) else {
            return nil
        }
        let alpha = parts.count == 4 ? parseAlpha(parts[3]) ?? 255 : 255
        return NativeRGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func parseHex(_ text: String) -> NativeRGBAColor? {
        let value = text.hasPrefix("#") ? String(text.dropFirst()) : text
        let characters = Array(value)
        let parts: [String]
        if [3, 4].contains(characters.count) {
            parts = characters.map { String([$0, $0]) }
        } else if characters.count == 6 || characters.count == 8 {
            parts = stride(from: 0, to: characters.count, by: 2).map {
                String(characters[$0..<min($0 + 2, characters.count)])
            }
        } else {
            return nil
        }
        guard parts.allSatisfy({ Int($0, radix: 16) != nil }) else {
            return nil
        }
        let values = parts.compactMap { Int($0, radix: 16) }
        guard values.count == 3 || values.count == 4 else {
            return nil
        }
        return NativeRGBAColor(red: values[0], green: values[1], blue: values[2], alpha: values.count == 4 ? values[3] : 255)
    }

    private static func parseRGB(_ text: String) -> NativeRGBAColor? {
        guard let match = text.firstMatch(of: /^rgba?\((.+)\)$/) else {
            return nil
        }
        let parts = String(match.1).split(separator: /[,\s\/]+/).map(String.init)
        guard parts.count == 3 || parts.count == 4,
              let red = parseChannel(parts[0]),
              let green = parseChannel(parts[1]),
              let blue = parseChannel(parts[2]) else {
            return nil
        }
        return NativeRGBAColor(red: red, green: green, blue: blue, alpha: parts.count == 4 ? parseAlpha(parts[3]) ?? 255 : 255)
    }

    private static func parseHSL(_ text: String) -> NativeRGBAColor? {
        guard let match = text.firstMatch(of: /^hsla?\((.+)\)$/) else {
            return nil
        }
        let parts = String(match.1).split(separator: /[,\s\/]+/).map(String.init)
        guard parts.count == 3 || parts.count == 4,
              let hue = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
              let saturation = percent(parts[1]),
              let lightness = percent(parts[2]) else {
            return nil
        }
        let rgb = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        return NativeRGBAColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: parts.count == 4 ? parseAlpha(parts[3]) ?? 255 : 255)
    }

    private static func parseChannel(_ text: String) -> Int? {
        let value: Double?
        if text.hasSuffix("%") {
            value = Double(text.dropLast()).map { $0 * 255 / 100 }
        } else {
            value = Double(text)
        }
        return value.map { min(255, max(0, Int(round($0)))) }
    }

    private static func parseAlpha(_ text: String) -> Int? {
        if text.hasSuffix("%") {
            return Double(text.dropLast()).map { min(255, max(0, Int(round($0 * 255 / 100)))) }
        }
        return Double(text).map { min(255, max(0, Int(round(($0 <= 1 ? $0 * 255 : $0))))) }
    }

    private static func percent(_ text: String) -> Double? {
        guard text.hasSuffix("%"), let value = Double(text.dropLast()) else {
            return nil
        }
        return value / 100
    }

    private static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> (Int, Int, Int) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let huePrime = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(huePrime.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2
        let tuple: (Double, Double, Double)
        switch huePrime {
        case 0..<1:
            tuple = (chroma, second, 0)
        case 1..<2:
            tuple = (second, chroma, 0)
        case 2..<3:
            tuple = (0, chroma, second)
        case 3..<4:
            tuple = (0, second, chroma)
        case 4..<5:
            tuple = (second, 0, chroma)
        default:
            tuple = (chroma, 0, second)
        }
        return (
            Int(round((tuple.0 + match) * 255)),
            Int(round((tuple.1 + match) * 255)),
            Int(round((tuple.2 + match) * 255))
        )
    }

    var hslText: String {
        let redValue = Double(red) / 255
        let greenValue = Double(green) / 255
        let blueValue = Double(blue) / 255
        let maxValue = max(redValue, greenValue, blueValue)
        let minValue = min(redValue, greenValue, blueValue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxValue == redValue {
            hue = 60 * ((greenValue - blueValue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == greenValue {
            hue = 60 * ((blueValue - redValue) / delta + 2)
        } else {
            hue = 60 * ((redValue - greenValue) / delta + 4)
        }
        return "hsl(\(Int(round((hue + 360).truncatingRemainder(dividingBy: 360)))), \(Int(round(saturation * 100)))%, \(Int(round(lightness * 100)))%)"
    }

    var cacheKey: String {
        SHA256.hash(data: Data("\(red),\(green),\(blue),\(alpha)".utf8)).hexString.prefix(16).description
    }

    private static let namedColors: [String: NativeRGBAColor] = [
        "black": NativeRGBAColor(red: 0, green: 0, blue: 0, alpha: 255),
        "white": NativeRGBAColor(red: 255, green: 255, blue: 255, alpha: 255),
        "red": NativeRGBAColor(red: 255, green: 0, blue: 0, alpha: 255),
        "green": NativeRGBAColor(red: 0, green: 128, blue: 0, alpha: 255),
        "blue": NativeRGBAColor(red: 0, green: 0, blue: 255, alpha: 255),
        "yellow": NativeRGBAColor(red: 255, green: 255, blue: 0, alpha: 255),
        "cyan": NativeRGBAColor(red: 0, green: 255, blue: 255, alpha: 255),
        "magenta": NativeRGBAColor(red: 255, green: 0, blue: 255, alpha: 255),
        "gray": NativeRGBAColor(red: 128, green: 128, blue: 128, alpha: 255),
        "grey": NativeRGBAColor(red: 128, green: 128, blue: 128, alpha: 255),
        "orange": NativeRGBAColor(red: 255, green: 165, blue: 0, alpha: 255),
        "purple": NativeRGBAColor(red: 128, green: 0, blue: 128, alpha: 255),
        "pink": NativeRGBAColor(red: 255, green: 192, blue: 203, alpha: 255),
        "brown": NativeRGBAColor(red: 165, green: 42, blue: 42, alpha: 255),
        "transparent": NativeRGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    ]
}

enum NativeQRCodeBuiltIn {
    static func results(query: String, codeType: String) throws -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return []
        }

        let type = ["qr", "aztec", "pdf417"].contains(codeType) ? codeType : "qr"
        let title = ["qr": "QR", "aztec": "Aztec", "pdf417": "PDF417"][type] ?? "QR"
        let imageURL = try codeImageURL(query: query, codeType: type)
        return [
            nativeResult(
                id: "\(type)-code",
                title: "\(title) Code",
                subtitle: query,
                text: query,
                tags: [type, "qr", "image", "png"],
                path: imageURL.path,
                previewImagePath: imageURL.path,
                accessories: [
                    CustomResultAccessory(text: title, symbolName: "qrcode", style: "green"),
                    CustomResultAccessory(text: "PNG", symbolName: "photo", style: "blue"),
                    CustomResultAccessory(text: "\(query.count) chars", symbolName: "textformat", style: "secondary")
                ],
                metadata: [
                    CustomResultMetadata(label: "Type", value: title, type: "text", url: nil),
                    CustomResultMetadata(label: "Text", value: query, type: "code", url: nil),
                    CustomResultMetadata(label: "PNG", value: imageURL.path, type: "link", url: imageURL.absoluteString)
                ]
            )
        ]
    }

    private static func codeImageURL(query: String, codeType: String) throws -> URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/cottage/qr", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data("\(codeType)\0\(query)".utf8)).hexString.prefix(16)
        let url = directory.appendingPathComponent("\(codeType)-\(digest).png")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let filterName: String
        switch codeType {
        case "aztec":
            filterName = "CIAztecCodeGenerator"
        case "pdf417":
            filterName = "CIPDF417BarcodeGenerator"
        default:
            filterName = "CIQRCodeGenerator"
        }
        guard let filter = CIFilter(name: filterName) else {
            throw NativeBuiltInError.message("Code generator unavailable")
        }
        filter.setValue(Data(query.utf8), forKey: "inputMessage")
        if codeType == "qr" {
            filter.setValue("M", forKey: "inputCorrectionLevel")
        }
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else {
            throw NativeBuiltInError.message("Code generation failed")
        }
        let representation = NSCIImageRep(ciImage: image)
        let nsImage = NSImage(size: representation.size)
        nsImage.addRepresentation(representation)
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NativeBuiltInError.message("PNG encoding failed")
        }
        try png.write(to: url, options: .atomic)
        return url
    }
}

enum NativeTranslatorBuiltIn {
    static func results(query: String, target: String) async throws -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return []
        }

        let source = detectedSource(query)
        var target = languages[target] == nil ? "zh-CN" : target
        if source == target {
            target = source == "en" ? "zh-CN" : "en"
        }
        do {
            let translation = try await myMemory(query: query, source: source, target: target)
            return [translationResult(query: query, source: source, target: target, provider: "MyMemory", translation: translation)]
        } catch {
            let translation = try await lingva(query: query, source: source, target: target)
            return [translationResult(query: query, source: source, target: target, provider: translation.provider, translation: translation.text)]
        }
    }

    private static func myMemory(query: String, source: String, target: String) async throws -> String {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "langpair", value: "\(source)|\(target)")
        ]
        guard let url = components?.url else {
            throw NativeBuiltInError.message("Invalid translation URL")
        }
        let data = try await data(from: url, timeout: 8)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["responseStatus"] as? Int,
              let response = json["responseData"] as? [String: Any],
              let text = response["translatedText"] as? String,
              status == 200,
              !text.isEmpty,
              text != query else {
            throw NativeBuiltInError.message("empty MyMemory translation")
        }
        return text
    }

    private static func lingva(query: String, source: String, target: String) async throws -> (text: String, provider: String) {
        let instances = [
            "https://lingva.ml",
            "https://translate.plausibility.cloud",
            "https://lingva.garudalinux.org",
            "https://lingva.lunar.icu",
            "https://lingva.thedaviddelta.com"
        ]
        var errors: [String] = []
        for instance in instances {
            do {
                let sourceCode = languages[source]?.lingva ?? source
                let targetCode = languages[target]?.lingva ?? target
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
                guard let url = URL(string: "\(instance)/api/v1/\(sourceCode)/\(targetCode)/\(encoded)") else {
                    continue
                }
                let data = try await data(from: url, timeout: 8)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["translation"] as? String,
                      !text.isEmpty else {
                    throw NativeBuiltInError.message("empty translation")
                }
                return (text, instance.replacingOccurrences(of: "https://", with: ""))
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        throw NativeBuiltInError.message(errors.suffix(3).joined(separator: "; "))
    }

    private static func data(from url: URL, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("CottagePanel/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private static func translationResult(
        query: String,
        source: String,
        target: String,
        provider: String,
        translation: String
    ) -> CustomActionResult {
        let languagePair = "\(languages[source]?.title ?? source) → \(languages[target]?.title ?? target)"
        return nativeResult(
            id: "translation",
            title: translation,
            subtitle: query,
            text: translation,
            tags: ["translate", source, target],
            accessories: [
                CustomResultAccessory(text: provider, symbolName: "network", style: "blue"),
                CustomResultAccessory(text: languagePair, symbolName: "arrow.right", style: "secondary")
            ],
            metadata: [
                CustomResultMetadata(label: "Provider", value: provider, type: "text", url: nil),
                CustomResultMetadata(label: "Source", value: languages[source]?.title ?? source, type: "text", url: nil),
                CustomResultMetadata(label: "Target", value: languages[target]?.title ?? target, type: "text", url: nil),
                CustomResultMetadata(label: "Original", value: query, type: "code", url: nil),
                CustomResultMetadata(label: "Translation", value: translation, type: "code", url: nil)
            ]
        )
    }

    private static func detectedSource(_ text: String) -> String {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF:
                return "ja"
            case 0xAC00...0xD7AF:
                return "ko"
            case 0x4E00...0x9FFF:
                return "zh-CN"
            case 0x0400...0x04FF:
                return "ru"
            default:
                continue
            }
        }
        return "en"
    }

    private static let languages: [String: (title: String, lingva: String)] = [
        "zh-CN": ("中文", "zh"),
        "en": ("English", "en"),
        "ja": ("日本語", "ja"),
        "ko": ("한국어", "ko"),
        "fr": ("Français", "fr"),
        "de": ("Deutsch", "de"),
        "es": ("Español", "es"),
        "ru": ("Русский", "ru")
    ]
}
