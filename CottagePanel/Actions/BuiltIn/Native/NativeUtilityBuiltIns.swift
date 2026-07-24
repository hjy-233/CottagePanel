// swiftlint:disable blanket_disable_command line_length
import CryptoKit
import Foundation

enum NativeJSONFormatterBuiltIn {
    static func results(query: String) -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return [
                nativeResult(
                    id: "help",
                    title: "输入 JSON",
                    subtitle: "格式化、压缩、校验 JSON",
                    text: "Paste JSON here.",
                    tags: ["help"]
                )
            ]
        }

        do {
            let data = Data(query.utf8)
            let value = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .withoutEscapingSlashes])
            let compactData = try JSONSerialization.data(withJSONObject: value, options: [.withoutEscapingSlashes])
            let pretty = nativeUTF8(prettyData)
            let compact = nativeUTF8(compactData)
            let summary = jsonSummary(value)
            return [
                nativeResult(id: "pretty", title: "Pretty JSON", subtitle: summary, text: pretty, tags: ["json", "pretty"]),
                nativeResult(id: "compact", title: "Compact JSON", subtitle: summary, text: compact, tags: ["json", "compact"]),
                nativeResult(id: "valid", title: "Valid JSON", subtitle: summary, text: summary, tags: ["json", "valid"])
            ]
        } catch {
            return [
                nativeResult(
                    id: "error",
                    title: "Invalid JSON",
                    subtitle: error.localizedDescription,
                    text: error.localizedDescription,
                    tags: ["error"],
                    isError: true
                )
            ]
        }
    }

    private static func jsonSummary(_ value: Any) -> String {
        if let dictionary = value as? [String: Any] {
            return "object, \(dictionary.count) keys"
        }
        if let array = value as? [Any] {
            return "array, \(array.count) items"
        }
        return String(describing: type(of: value))
    }
}

enum NativeWordsCountBuiltIn {
    static func results(query: String) -> [CustomActionResult] {
        guard !query.isEmpty else {
            return [
                nativeResult(
                    id: "help",
                    title: "输入文本",
                    subtitle: "统计字符、单词、行数、中英文、阅读时间",
                    text: "Paste text here.",
                    tags: ["help"]
                )
            ]
        }

        let englishWords = query.matches(of: /[A-Za-z]+(?:'[A-Za-z]+)?/).count
        let chineseCharacters = query.unicodeScalars.filter { 0x4E00...0x9FFF ~= $0.value }.count
        let punctuation = query.unicodeScalars.filter {
            CharacterSet.punctuationCharacters.contains($0)
                || CharacterSet.symbols.contains($0)
        }.count
        let whitespace = query.unicodeScalars.filter { CharacterSet.whitespacesAndNewlines.contains($0) }.count
        let charactersNoSpace = query.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }.count
        let paragraphs = query.split(separator: /\n\s*\n/)
            .filter { !String($0).trimmedSearchText.isEmpty }
            .count
        let readMinutes = max(1, Int(round(Double(englishWords) / 220 + Double(chineseCharacters) / 400)))
        let items = [
            ("chars", "Characters", "\(query.count)"),
            ("chars-nospace", "Characters No Spaces", "\(charactersNoSpace)"),
            ("words", "Words 中文+English", "\(englishWords + chineseCharacters)"),
            ("english", "English Words", "\(englishWords)"),
            ("chinese", "Chinese Characters", "\(chineseCharacters)"),
            ("lines", "Lines", "\(query.components(separatedBy: .newlines).count)"),
            ("paragraphs", "Paragraphs", "\(paragraphs)"),
            ("bytes", "UTF-8 Bytes", "\(Data(query.utf8).count)"),
            ("punctuation", "Punctuation", "\(punctuation)"),
            ("spaces", "Whitespace", "\(whitespace)"),
            ("reading", "Reading Time", "\(readMinutes) min")
        ]
        return items.map { id, title, value in
            nativeResult(id: id, title: "\(title): \(value)", subtitle: "Word count", text: value, tags: ["words", id])
        }
    }
}

enum NativeHashBuiltIn {
    static func results(query: String) async throws -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return [
                nativeResult(
                    id: "help",
                    title: "输入文本或文件路径",
                    subtitle: "~/Downloads/file.zip 或 hello world",
                    text: "输入普通文本会计算文本 hash；输入存在的文件路径会计算文件 hash。",
                    tags: ["help"]
                )
            ]
        }

        let source = nativeHashSource(query)
        let data: Data
        let subtitle: String
        let sourceTag: String
        switch source {
        case .file(let url):
            data = try Data(contentsOf: url)
            subtitle = url.path
            sourceTag = "file"
        case .text(let text):
            data = Data(text.utf8)
            subtitle = "Text input"
            sourceTag = "text"
        }

        let digests = try await [
            ("md5", Insecure.MD5.hash(data: data).hexString),
            ("sha1", Insecure.SHA1.hash(data: data).hexString),
            ("sha224", nativeOpenSSLDigest("sha224", data: data)),
            ("sha256", SHA256.hash(data: data).hexString),
            ("sha384", SHA384.hash(data: data).hexString),
            ("sha512", SHA512.hash(data: data).hexString),
            ("blake2b", nativeOpenSSLDigest("blake2b512", data: data)),
            ("blake2s", nativeOpenSSLDigest("blake2s256", data: data))
        ]

        return digests.map { name, digest in
            nativeResult(
                id: name,
                title: "\(name.uppercased()): \(digest)",
                subtitle: subtitle,
                text: digest,
                tags: ["hash", name, sourceTag]
            )
        }
    }

    private static func nativeOpenSSLDigest(_ algorithm: String, data: Data) async throws -> String {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cottage-hash-\(UUID().uuidString)")
        try data.write(to: temporaryURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let output = try await nativeProcessOutput(
            executable: "/usr/bin/openssl",
            arguments: ["dgst", "-\(algorithm)", "-r", temporaryURL.path],
            timeout: 8
        )
        guard output.status == 0 else {
            throw NativeBuiltInError.message(nativeUTF8(output.stderr))
        }

        return nativeUTF8(output.stdout)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
    }
}

private enum NativeHashSource {
    case file(URL)
    case text(String)
}

private func nativeHashSource(_ query: String) -> NativeHashSource {
    if query.hasPrefix("file://"),
       let url = URL(string: query),
       url.isFileURL,
       FileManager.default.fileExists(atPath: url.path) {
        return .file(url)
    }

    let expanded = NSString(string: query).expandingTildeInPath
    if FileManager.default.fileExists(atPath: expanded) {
        return .file(URL(fileURLWithPath: expanded))
    }

    return .text(query)
}

enum NativeUnixTimeConverterBuiltIn {
    static func results(query: String) -> [CustomActionResult] {
        do {
            let parsed = try parseDate(query.trimmedSearchText)
            let date = parsed.date
            let source = parsed.source
            let utcFormatter = DateFormatter()
            utcFormatter.locale = Locale(identifier: "en_US_POSIX")
            utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            utcFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
            let localFormatter = DateFormatter()
            localFormatter.locale = Locale(identifier: "en_US_POSIX")
            localFormatter.timeZone = .current
            localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            let seconds = Int(date.timeIntervalSince1970)
            let milliseconds = Int(date.timeIntervalSince1970 * 1000)
            let values = [
                ("unix", "Unix Seconds", "\(seconds)"),
                ("unix-ms", "Unix Milliseconds", "\(milliseconds)"),
                ("local", "Local Time", localFormatter.string(from: date)),
                ("utc", "UTC", utcFormatter.string(from: date)),
                ("iso", "ISO 8601 Local", isoFormatter.string(from: date)),
                ("rfc3339", "RFC3339 UTC", isoFormatter.string(from: date)),
                ("date-only", "Date", date.formatted(.iso8601.year().month().day())),
                ("time-only", "Time", date.formatted(date: .omitted, time: .standard))
            ]
            let sourceQuery = query.isEmpty ? "now" : query
            return values.map { id, title, text in
                nativeResult(
                    id: id,
                    title: "\(title): \(text)",
                    subtitle: "\(sourceQuery) · \(source)",
                    text: text,
                    tags: ["time", id, source]
                )
            }
        } catch {
            return [
                nativeResult(
                    id: "error",
                    title: "无法解析时间",
                    subtitle: error.localizedDescription,
                    text: error.localizedDescription,
                    tags: ["error"],
                    isError: true
                )
            ]
        }
    }

    private static func parseDate(_ query: String) throws -> (date: Date, source: String) {
        if query.isEmpty || ["now", "今天", "现在"].contains(query.lowercased()) {
            return (Date(), "now")
        }
        let lower = query.lowercased()
        if lower == "yesterday" || lower == "昨天" {
            return (Date().addingTimeInterval(-86_400), "relative")
        }
        if lower == "tomorrow" || lower == "明天" {
            return (Date().addingTimeInterval(86_400), "relative")
        }
        if let relative = parseRelative(lower) {
            return (relative, "relative")
        }
        if let numeric = Double(query.replacingOccurrences(of: ",", with: "")) {
            let seconds = abs(numeric) > 10_000_000_000 ? numeric / 1000 : numeric
            return (Date(timeIntervalSince1970: seconds), abs(numeric) > 10_000_000_000 ? "milliseconds" : "seconds")
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: query) {
                return (date, "date string")
            }
        }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: query.replacingOccurrences(of: "Z", with: "+00:00")) {
            return (date, "iso8601")
        }
        throw NativeBuiltInError.message("Unsupported date")
    }

    private static func parseRelative(_ text: String) -> Date? {
        guard let match = text.firstMatch(of: /^([+-]?\d+)\s*(s|sec|second|m|min|minute|h|hour|d|day)$/) else {
            return nil
        }

        let value = Double(match.1) ?? 0
        let unit = String(match.2)
        let seconds: Double
        if unit.hasPrefix("s") {
            seconds = value
        } else if unit.hasPrefix("m") {
            seconds = value * 60
        } else if unit.hasPrefix("h") {
            seconds = value * 3600
        } else {
            seconds = value * 86_400
        }
        return Date().addingTimeInterval(seconds)
    }
}

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum NativeBuiltInError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message.isEmpty ? "Action failed" : message
        }
    }
}
