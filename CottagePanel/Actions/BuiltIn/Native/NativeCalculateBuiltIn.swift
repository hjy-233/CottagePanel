// swiftlint:disable blanket_disable_command cyclomatic_complexity file_length line_length type_body_length
import Foundation

enum NativeCalculateBuiltIn {
    static func results(query: String) async throws -> [CustomActionResult] {
        let query = query.trimmedSearchText
        guard !query.isEmpty else {
            return [
                nativeResult(
                    id: "help",
                    title: "输入表达式",
                    subtitle: "10cm in dm, 100 usd in cny, 5pm london in tokyo, 35 days ago, square root of 625",
                    text: "支持数学、货币/加密货币、时区、相对日期、设计单位、更多单位、增长计算",
                    tags: ["help"]
                )
            ]
        }

        do {
            if let results = growth(query) { return results }
            if let results = percentage(query) { return results }
            if let results = try await currency(query) { return results }
            if let results = try unit(query) { return results }
            if let results = timezone(query) { return results }
            if let results = relativeDate(query) { return results }
            if let results = clockDifference(query) { return results }
            if let results = dateDifference(query) { return results }
            return try expression(query)
        } catch {
            return [
                nativeResult(
                    id: "error",
                    title: "无法计算",
                    subtitle: error.localizedDescription,
                    text: error.localizedDescription,
                    tags: ["error"],
                    isError: true
                )
            ]
        }
    }

    private static func expression(_ query: String) throws -> [CustomActionResult] {
        let parser = NativeMathParser(query)
        let value = try parser.parse()
        return numericResults(value: value, query: query)
    }

    private static func numericResults(value: Double, query: String) -> [CustomActionResult] {
        let text = format(value)
        var results = [
            nativeResult(id: "result", title: text, subtitle: query, text: text, tags: ["result", "copy"])
        ]
        results.append(nativeResult(
            id: "percent",
            title: "\(text)% = \(format(value / 100))",
            subtitle: "percentage",
            text: format(value / 100),
            tags: ["percent"]
        ))
        if value.isFinite, value.rounded() == value {
            let integer = Int(value)
            results.append(nativeResult(id: "hex", title: "hex: \(String(integer, radix: 16))", subtitle: "integer conversion", text: String(integer, radix: 16), tags: ["hex", "integer"]))
            results.append(nativeResult(id: "bin", title: "bin: \(String(integer, radix: 2))", subtitle: "integer conversion", text: String(integer, radix: 2), tags: ["bin", "integer"]))
            results.append(nativeResult(id: "oct", title: "oct: \(String(integer, radix: 8))", subtitle: "integer conversion", text: String(integer, radix: 8), tags: ["oct", "integer"]))
        }
        return results
    }

    private static func percentage(_ query: String) -> [CustomActionResult]? {
        if let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s*(?:%|percent)\s*(?:of|on|\*)\s*([-+]?\d+(?:\.\d+)?)$/) {
            let result = (Double(match.1) ?? 0) / 100 * (Double(match.2) ?? 0)
            return [nativeResult(id: "percentage", title: format(result), subtitle: query, text: format(result), tags: ["percent"])]
        }
        if let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s+(?:is|=)\s+what\s+(?:%|percent)\s+of\s+([-+]?\d+(?:\.\d+)?)$/) {
            let base = Double(match.2) ?? 0
            guard base != 0 else { return nil }
            let result = (Double(match.1) ?? 0) / base * 100
            return [nativeResult(id: "percentage", title: "\(format(result))%", subtitle: query, text: "\(format(result))%", tags: ["percent"])]
        }
        return nil
    }

    private static func growth(_ query: String) -> [CustomActionResult]? {
        if let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s*(?:after|plus|increase(?:d)? by)\s*([-+]?\d+(?:\.\d+)?)\s*(?:%|percent)$/) {
            let result = (Double(match.1) ?? 0) * (1 + (Double(match.2) ?? 0) / 100)
            return [nativeResult(id: "growth", title: format(result), subtitle: query, text: format(result), tags: ["growth", "percent"])]
        }
        if let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s*(?:discount|off|minus|decrease(?:d)? by)\s*([-+]?\d+(?:\.\d+)?)\s*(?:%|percent)$/) {
            let result = (Double(match.1) ?? 0) * (1 - (Double(match.2) ?? 0) / 100)
            return [nativeResult(id: "discount", title: format(result), subtitle: query, text: format(result), tags: ["discount", "percent"])]
        }
        if let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s+(?:at|compound)\s+([-+]?\d+(?:\.\d+)?)\s*(?:%|percent)\s+(?:for|after)\s+([-+]?\d+(?:\.\d+)?)\s*(?:years?|y)$/) {
            let result = (Double(match.1) ?? 0) * pow(1 + (Double(match.2) ?? 0) / 100, Double(match.3) ?? 0)
            return [nativeResult(id: "compound", title: format(result), subtitle: query, text: format(result), tags: ["growth", "compound"])]
        }
        return nil
    }

    private static func unit(_ query: String) throws -> [CustomActionResult]? {
        guard let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s*([a-zA-Zµμ]+(?:\^?\d+|[²³])?)\s+(?:to|in|as|为|到|转)\s+([a-zA-Zµμ]+(?:\^?\d+|[²³])?)(?:\s+(?:at|@)\s+(\d+(?:\.\d+)?)\s*(ppi|dpi|x))?$/) else {
            return nil
        }

        let value = Double(match.1) ?? 0
        let sourceText = String(match.2)
        let targetText = String(match.3)
        let density = match.4.map(String.init) ?? ""
        let densityUnit = match.5.map(String.init) ?? ""
        if let result = designUnit(
            value: value,
            source: sourceText,
            target: targetText,
            density: density,
            unit: densityUnit
        ) {
            return [nativeResult(id: "design-unit", title: "\(format(result.value)) \(result.unit)", subtitle: query, text: format(result.value), tags: ["design", "unit"])]
        }
        let source = parseUnit(sourceText)
        let target = parseUnit(targetText)
        if ["c", "f", "k"].contains(source.name) || ["c", "f", "k"].contains(target.name) {
            let result = try temperature(value: value, source: source.name, target: target.name)
            return [nativeResult(id: "unit", title: "\(format(result)) \(target.name)", subtitle: query, text: format(result), tags: ["unit", "convert"])] + numericDetails(result)
        }
        guard let sourceFactor = unitFactors[source.name],
              let targetFactor = unitFactors[target.name],
              sourceFactor.dimension == targetFactor.dimension,
              source.power == target.power else {
            throw NativeBuiltInError.message("unsupported unit conversion")
        }
        let result = value * pow(sourceFactor.factor, Double(source.power)) / pow(targetFactor.factor, Double(target.power))
        let label = target.power == 1 ? target.name : "\(target.name)^\(target.power)"
        return [nativeResult(id: "unit", title: "\(format(result)) \(label)", subtitle: query, text: format(result), tags: ["unit", "convert"])] + numericDetails(result)
    }

    private static func numericDetails(_ value: Double) -> [CustomActionResult] {
        Array(numericResults(value: value, query: "integer conversion").dropFirst())
    }

    private static func temperature(value: Double, source: String, target: String) throws -> Double {
        let celsius: Double
        switch source {
        case "c": celsius = value
        case "f": celsius = (value - 32) * 5 / 9
        case "k": celsius = value - 273.15
        default: throw NativeBuiltInError.message("unsupported temperature unit")
        }
        switch target {
        case "c": return celsius
        case "f": return celsius * 9 / 5 + 32
        case "k": return celsius + 273.15
        default: throw NativeBuiltInError.message("unsupported temperature unit")
        }
    }

    private static func designUnit(
        value: Double,
        source: String,
        target: String,
        density: String,
        unit: String
    ) -> (value: Double, unit: String)? {
        let source = normalizeDesignUnit(source)
        let target = normalizeDesignUnit(target)
        guard ["px", "pt", "in"].contains(source), ["px", "pt", "in"].contains(target) else {
            return nil
        }
        var ppi = Double(density) ?? 72
        if unit == "x" {
            ppi *= 72
        }
        let inches: Double
        switch source {
        case "px": inches = value / ppi
        case "pt": inches = value / 72
        default: inches = value
        }
        let result: Double
        switch target {
        case "px": result = inches * ppi
        case "pt": result = inches * 72
        default: result = inches
        }
        return (result, target)
    }

    private static func normalizeDesignUnit(_ text: String) -> String {
        switch text.lowercased() {
        case "point", "points": return "pt"
        case "inch", "inches": return "in"
        default: return text.lowercased()
        }
    }

    private static func clockDifference(_ query: String) -> [CustomActionResult]? {
        guard let match = query.firstMatch(of: /^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:to|until|-|到|至)\s*(\d{1,2}):(\d{2})(?::(\d{2}))?$/) else {
            return nil
        }
        let start = clockSeconds(hour: String(match.1), minute: String(match.2), second: match.3.map(String.init) ?? "")
        var end = clockSeconds(hour: String(match.4), minute: String(match.5), second: match.6.map(String.init) ?? "")
        if end < start { end += 86_400 }
        return [timeResult(id: "time-range", seconds: end - start, query: query)]
    }

    private static func dateDifference(_ query: String) -> [CustomActionResult]? {
        guard query.lowercased().hasPrefix("time diff")
            || query.range(of: #"\d{4}[-/.]"#, options: .regularExpression) != nil else {
            return nil
        }
        guard let match = query.firstMatch(of: /^(?:time\s*diff\s+)?(.+?)\s+(?:to|until|到|至)\s+(.+)$/) else {
            return nil
        }
        guard let start = parseSimpleDate(String(match.1)), let end = parseSimpleDate(String(match.2)) else {
            return nil
        }
        return [timeResult(id: "time-diff", seconds: abs(end.timeIntervalSince(start)), query: query)]
    }

    private static func relativeDate(_ query: String) -> [CustomActionResult]? {
        let lower = query.lowercased()
        let now = Date()
        if let match = lower.firstMatch(of: /^(?:in\s+)?(\d+)\s+(days?|weeks?|months?|years?)\s*(?:from now)?$/) {
            let result = addRelative(now, amount: Int(match.1) ?? 0, unit: String(match.2))
            return [dateResult(id: "relative-date", date: result, query: query)]
        }
        if let match = lower.firstMatch(of: /^(\d+)\s+(days?|weeks?|months?|years?)\s+ago$/) {
            let result = addRelative(now, amount: -(Int(match.1) ?? 0), unit: String(match.2))
            return [dateResult(id: "relative-date", date: result, query: query)]
        }
        if let match = lower.firstMatch(of: /^days?\s+(?:until|to)\s+(.+)$/),
           let target = parseSimpleDate(String(match.1)) {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: Calendar.current.startOfDay(for: target)).day ?? 0
            return [nativeResult(id: "days-until", title: "\(days) days", subtitle: query, text: "\(days)", tags: ["date", "relative"])]
        }
        return nil
    }

    private static func timezone(_ query: String) -> [CustomActionResult]? {
        let lower = query.lowercased()
        if let match = lower.firstMatch(of: /^time\s+in\s+([a-zA-Z_ \/-]+)$/),
           let zone = timeZone(String(match.1)) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm zzz"
            formatter.timeZone = zone
            return [nativeResult(id: "timezone-now", title: formatter.string(from: Date()), subtitle: "time in \(zone.identifier)", text: Date().formatted(.iso8601), tags: ["timezone"])]
        }
        guard let match = lower.firstMatch(of: /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+([a-zA-Z_ \/-]+)\s+(?:to|in)\s+([a-zA-Z_ \/-]+)$/),
              let sourceZone = timeZone(String(match.4)),
              let targetZone = timeZone(String(match.5)) else {
            return nil
        }
        var hour = Int(match.1) ?? 0
        let minute = Int(match.2.map(String.init) ?? "") ?? 0
        let meridiem = match.3.map(String.init) ?? ""
        if meridiem == "pm", hour != 12 { hour += 12 }
        if meridiem == "am", hour == 12 { hour = 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sourceZone
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let sourceDate = calendar.date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm zzz"
        formatter.timeZone = targetZone
        return [nativeResult(id: "timezone", title: formatter.string(from: sourceDate), subtitle: "\(sourceZone.identifier) → \(targetZone.identifier)", text: sourceDate.formatted(.iso8601), tags: ["timezone"])]
    }

    private static func currency(_ query: String) async throws -> [CustomActionResult]? {
        guard let match = query.firstMatch(of: /^([-+]?\d+(?:\.\d+)?)\s*([a-zA-Z]+)\s+(?:to|in|as|为|到|转)\s+([a-zA-Z]+)$/) else {
            return nil
        }
        let amount = Double(match.1) ?? 0
        let source = String(match.2).lowercased()
        let target = String(match.3).lowercased()
        if cryptoIDs[source] != nil {
            let result = try await crypto(amount: amount, source: source, target: target)
            return [result]
        }
        if cryptoIDs[target] != nil {
            let result = try await toCrypto(amount: amount, source: source, target: target)
            return [result]
        }
        guard let sourceCode = fiatAliases[source], let targetCode = fiatAliases[target] else {
            return nil
        }
        let url = URL(string: "https://open.er-api.com/v6/latest/\(sourceCode)")!
        let json = try await cachedJSON(url: url, name: "fiat-\(sourceCode.lowercased()).json", ttl: 12 * 3600)
        guard let rates = json["rates"] as? [String: Any], let rate = rates[targetCode] as? Double else {
            throw NativeBuiltInError.message("currency rate unavailable")
        }
        let result = amount * rate
        return [nativeResult(id: "currency", title: "\(format(result)) \(targetCode)", subtitle: "\(format(amount)) \(sourceCode) · ExchangeRate-API open access", text: format(result), tags: ["currency", "fiat"])]
    }

    private static func crypto(amount: Double, source: String, target: String) async throws -> CustomActionResult {
        let coinID = cryptoIDs[source] ?? source
        let targetCode = (fiatAliases[target] ?? target.uppercased()).lowercased()
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(coinID)&vs_currencies=\(targetCode)")!
        let json = try await cachedJSON(url: url, name: "crypto-\(coinID)-\(targetCode).json", ttl: 120)
        guard let coin = json[coinID] as? [String: Any], let price = coin[targetCode] as? Double else {
            throw NativeBuiltInError.message("crypto price unavailable")
        }
        let result = amount * price
        return nativeResult(id: "crypto", title: "\(format(result)) \(targetCode.uppercased())", subtitle: "\(format(amount)) \(source.uppercased()) · CoinGecko", text: format(result), tags: ["currency", "crypto"])
    }

    private static func toCrypto(amount: Double, source: String, target: String) async throws -> CustomActionResult {
        let coinID = cryptoIDs[target] ?? target
        let sourceCode = (fiatAliases[source] ?? source.uppercased()).lowercased()
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(coinID)&vs_currencies=\(sourceCode)")!
        let json = try await cachedJSON(url: url, name: "crypto-\(coinID)-\(sourceCode).json", ttl: 120)
        guard let coin = json[coinID] as? [String: Any], let price = coin[sourceCode] as? Double else {
            throw NativeBuiltInError.message("crypto price unavailable")
        }
        let result = amount / price
        return nativeResult(id: "crypto", title: "\(format(result)) \(target.uppercased())", subtitle: "\(format(amount)) \(sourceCode.uppercased()) · CoinGecko", text: format(result), tags: ["currency", "crypto"])
    }

    private static func cachedJSON(url: URL, name: String, ttl: TimeInterval) async throws -> [String: Any] {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/cottage/calculate", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cacheURL = directory.appendingPathComponent(name)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) <= ttl,
           let data = try? Data(contentsOf: cacheURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.setValue("CottagePanel/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        try data.write(to: cacheURL, options: .atomic)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NativeBuiltInError.message("invalid JSON response")
        }
        return json
    }

    private static func parseUnit(_ text: String) -> (name: String, power: Int) {
        var normalized = text.lowercased()
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "µ", with: "u")
        normalized = unitWords[normalized] ?? normalized
        guard let match = normalized.firstMatch(of: /^([a-z]+)(?:\^?([23]))?$/) else {
            return (normalized, 1)
        }
        return (String(match.1), Int(match.2.map(String.init) ?? "") ?? 1)
    }

    private static func timeZone(_ text: String) -> TimeZone? {
        let key = text.lowercased().unicodeScalars
            .filter { CharacterSet.letters.contains($0) }
            .map(String.init)
            .joined()
        if let alias = zoneAliases[key] {
            return TimeZone(identifier: alias)
        }
        return TimeZone(identifier: text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_"))
    }

    private static func clockSeconds(hour: String, minute: String, second: String) -> TimeInterval {
        let hours = Int(hour) ?? 0
        let minutes = Int(minute) ?? 0
        let seconds = Int(second) ?? 0
        return Double(hours * 3600 + minutes * 60 + seconds)
    }

    private static func timeResult(id: String, seconds: TimeInterval, query: String) -> CustomActionResult {
        let days = seconds / 86_400
        let hours = seconds / 3600
        let minutes = seconds / 60
        return nativeResult(id: id, title: duration(seconds), subtitle: "\(format(days)) days / \(format(hours)) hours / \(format(minutes)) minutes", text: format(seconds), tags: ["time", "date", "diff"])
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        var total = Int(seconds)
        let days = total / 86_400
        total %= 86_400
        let hours = total / 3600
        total %= 3600
        let minutes = total / 60
        total %= 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if total > 0 || parts.isEmpty { parts.append("\(total)s") }
        return parts.joined(separator: " ")
    }

    private static func parseSimpleDate(_ text: String) -> Date? {
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "MM/dd/yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: text.trimmedSearchText) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: text.trimmedSearchText)
    }

    private static func dateResult(id: String, date: Date, query: String) -> CustomActionResult {
        let text = date.formatted(.iso8601.year().month().day())
        return nativeResult(id: id, title: text, subtitle: query, text: text, tags: ["date", "relative"])
    }

    private static func addRelative(_ date: Date, amount: Int, unit: String) -> Date {
        let component: Calendar.Component
        if unit.hasPrefix("day") {
            component = .day
        } else if unit.hasPrefix("week") {
            component = .weekOfYear
        } else if unit.hasPrefix("month") {
            component = .month
        } else {
            component = .year
        }
        return Calendar.current.date(byAdding: component, value: amount, to: date) ?? date
    }

    private static func format(_ value: Double) -> String {
        guard value.isFinite else { return "\(value)" }
        if value.rounded() == value { return "\(Int(value))" }
        return String(format: "%.12g", value)
    }

    private static let fiatAliases = [
        "rmb": "CNY", "yuan": "CNY", "usd": "USD", "dollar": "USD", "dollars": "USD",
        "cny": "CNY", "eur": "EUR", "euro": "EUR", "gbp": "GBP", "jpy": "JPY",
        "yen": "JPY", "hkd": "HKD", "cad": "CAD", "aud": "AUD", "sgd": "SGD", "krw": "KRW"
    ]
    private static let cryptoIDs = [
        "btc": "bitcoin", "bitcoin": "bitcoin", "eth": "ethereum", "ethereum": "ethereum",
        "sol": "solana", "solana": "solana", "doge": "dogecoin", "dogecoin": "dogecoin",
        "bnb": "binancecoin", "xrp": "ripple", "ada": "cardano", "ton": "the-open-network"
    ]
    private static let zoneAliases = [
        "shanghai": "Asia/Shanghai", "beijing": "Asia/Shanghai", "tokyo": "Asia/Tokyo",
        "seoul": "Asia/Seoul", "london": "Europe/London", "paris": "Europe/Paris",
        "berlin": "Europe/Berlin", "dubai": "Asia/Dubai", "newyork": "America/New_York",
        "nyc": "America/New_York", "la": "America/Los_Angeles", "losangeles": "America/Los_Angeles",
        "sf": "America/Los_Angeles", "sydney": "Australia/Sydney", "singapore": "Asia/Singapore",
        "utc": "UTC"
    ]
    private static let unitWords = [
        "micrometer": "um", "micrometers": "um", "millimeter": "mm", "millimeters": "mm",
        "centimeter": "cm", "centimeters": "cm", "decimeter": "dm", "decimeters": "dm",
        "meter": "m", "meters": "m", "kilometer": "km", "kilometers": "km",
        "inch": "in", "inches": "in", "foot": "ft", "feet": "ft", "yard": "yd",
        "yards": "yd", "mile": "mi", "miles": "mi", "gram": "g", "grams": "g",
        "kilogram": "kg", "kilograms": "kg", "pound": "lb", "pounds": "lb",
        "ounce": "oz", "ounces": "oz", "liter": "l", "liters": "l", "teaspoon": "tsp",
        "teaspoons": "tsp", "tablespoon": "tbsp", "tablespoons": "tbsp", "cups": "cup",
        "second": "s", "seconds": "s", "minute": "min", "minutes": "min", "hour": "h",
        "hours": "h", "days": "day", "bytes": "byte", "kilobyte": "kb",
        "megabyte": "mb", "gigabyte": "gb", "terabyte": "tb", "pixel": "px",
        "pixels": "px", "point": "pt", "points": "pt"
    ]
    private static let unitFactors: [String: (dimension: String, factor: Double)] = [
        "um": ("length", 0.000001), "mm": ("length", 0.001), "cm": ("length", 0.01),
        "dm": ("length", 0.1), "m": ("length", 1), "km": ("length", 1000),
        "in": ("length", 0.0254), "ft": ("length", 0.3048), "yd": ("length", 0.9144),
        "mi": ("length", 1609.344), "mg": ("mass", 0.001), "g": ("mass", 1),
        "kg": ("mass", 1000), "oz": ("mass", 28.349523125), "lb": ("mass", 453.59237),
        "ml": ("volume", 0.001), "l": ("volume", 1), "tsp": ("volume", 0.00492892159375),
        "tbsp": ("volume", 0.01478676478125), "cup": ("volume", 0.2365882365),
        "pt": ("volume", 0.473176473), "qt": ("volume", 0.946352946),
        "gal": ("volume", 3.785411784), "ms": ("time", 0.001), "s": ("time", 1),
        "sec": ("time", 1), "min": ("time", 60), "h": ("time", 3600), "hr": ("time", 3600),
        "day": ("time", 86400), "b": ("data", 1), "byte": ("data", 1), "kb": ("data", 1000),
        "mb": ("data", 1000 * 1000), "gb": ("data", 1000 * 1000 * 1000),
        "tb": ("data", 1000 * 1000 * 1000 * 1000), "kib": ("data", 1024),
        "mib": ("data", 1024 * 1024), "gib": ("data", 1024 * 1024 * 1024),
        "tib": ("data", 1024 * 1024 * 1024 * 1024), "mps": ("speed", 1),
        "kmh": ("speed", 1000 / 3600), "mph": ("speed", 1609.344 / 3600),
        "knot": ("speed", 1852 / 3600), "pa": ("pressure", 1), "kpa": ("pressure", 1000),
        "bar": ("pressure", 100000), "psi": ("pressure", 6894.757293168), "atm": ("pressure", 101325),
        "j": ("energy", 1), "kj": ("energy", 1000), "cal": ("energy", 4.184),
        "kcal": ("energy", 4184), "wh": ("energy", 3600), "kwh": ("energy", 3600000),
        "w": ("power", 1), "kw": ("power", 1000), "hp": ("power", 745.699871582),
        "hz": ("frequency", 1), "khz": ("frequency", 1000), "mhz": ("frequency", 1000 * 1000),
        "ghz": ("frequency", 1000 * 1000 * 1000), "deg": ("angle", Double.pi / 180),
        "degree": ("angle", Double.pi / 180), "rad": ("angle", 1)
    ]
}

private final class NativeMathParser {
    private let tokens: [String]
    private var index = 0

    init(_ text: String) {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")
        tokens = NativeMathParser.tokenize(NativeMathParser.normalizeWords(normalized))
    }

    func parse() throws -> Double {
        let value = try comparison()
        guard index == tokens.count else {
            throw NativeBuiltInError.message("unsupported expression")
        }
        return value
    }

    private func comparison() throws -> Double {
        var left = try expression()
        while let token = peek(), ["==", "!=", "<", "<=", ">", ">="].contains(token) {
            advance()
            let right = try expression()
            switch token {
            case "==": left = left == right ? 1 : 0
            case "!=": left = left != right ? 1 : 0
            case "<": left = left < right ? 1 : 0
            case "<=": left = left <= right ? 1 : 0
            case ">": left = left > right ? 1 : 0
            default: left = left >= right ? 1 : 0
            }
        }
        return left
    }

    private func expression() throws -> Double {
        var value = try term()
        while let token = peek(), token == "+" || token == "-" {
            advance()
            value = token == "+" ? value + (try term()) : value - (try term())
        }
        return value
    }

    private func term() throws -> Double {
        var value = try power()
        while let token = peek(), ["*", "/", "//", "%"].contains(token) {
            advance()
            let right = try power()
            switch token {
            case "*": value *= right
            case "/": value /= right
            case "//": value = floor(value / right)
            default: value = value.truncatingRemainder(dividingBy: right)
            }
        }
        return value
    }

    private func power() throws -> Double {
        var value = try unary()
        while peek() == "**" {
            advance()
            value = pow(value, try unary())
        }
        return value
    }

    private func unary() throws -> Double {
        if peek() == "+" {
            advance()
            return try unary()
        }
        if peek() == "-" {
            advance()
            return -(try unary())
        }
        return try primary()
    }

    private func primary() throws -> Double {
        guard let token = peek() else {
            throw NativeBuiltInError.message("unexpected end")
        }
        if token == "(" {
            advance()
            let value = try comparison()
            guard peek() == ")" else { throw NativeBuiltInError.message("missing )") }
            advance()
            return value
        }
        if let value = Double(token.replacingOccurrences(of: ",", with: "_")) {
            advance()
            if peek() == "%" {
                advance()
                return value / 100
            }
            return value
        }
        if let constant = NativeMathParser.constants[token] {
            advance()
            return constant
        }
        if let function = NativeMathParser.functions[token] {
            advance()
            guard peek() == "(" else { throw NativeBuiltInError.message("missing function arguments") }
            advance()
            var arguments: [Double] = []
            if peek() != ")" {
                repeat {
                    arguments.append(try comparison())
                    if peek() == "," {
                        advance()
                    } else {
                        break
                    }
                } while true
            }
            guard peek() == ")" else { throw NativeBuiltInError.message("missing )") }
            advance()
            return try function(arguments)
        }
        throw NativeBuiltInError.message("unsupported expression")
    }

    private func peek() -> String? {
        index < tokens.count ? tokens[index] : nil
    }

    private func advance() {
        index += 1
    }

    private static func tokenize(_ text: String) -> [String] {
        let pattern = #"==|!=|<=|>=|\*\*|//|[()+\-*/%,<>]|[a-zπτ]+|[-+]?\d+(?:,\d{3})*(?:\.\d+)?|[-+]?\d*\.\d+|[-+]?\d+"#
        return (try? NSRegularExpression(pattern: pattern)).map { regex in
            regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range, in: text).map { String(text[$0]) }
            }
        } ?? []
    }

    private static func normalizeWords(_ text: String) -> String {
        let replacements = [
            (#"^square root of (.+)$"#, #"sqrt($1)"#),
            (#"^sqrt of (.+)$"#, #"sqrt($1)"#),
            (#"^cube root of (.+)$"#, #"cbrt($1)"#),
            (#"^(.+?)\s+to the power of\s+(.+)$"#, #"($1)**($2)"#),
            (#"^(.+?)\s+power\s+(.+)$"#, #"($1)**($2)"#),
            (#"^(.+?)\s+squared$"#, #"($1)**2"#),
            (#"^(.+?)\s+cubed$"#, #"($1)**3"#),
            (#"^(.+?)\s+plus\s+(.+)$"#, #"($1)+($2)"#),
            (#"^(.+?)\s+minus\s+(.+)$"#, #"($1)-($2)"#),
            (#"^(.+?)\s+times\s+(.+)$"#, #"($1)*($2)"#),
            (#"^(.+?)\s+divided by\s+(.+)$"#, #"($1)/($2)"#)
        ]
        for (pattern, replacement) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: replacement
                )
            }
        }
        return text.replacingOccurrences(of: "％", with: "%")
    }

    private static let constants = ["pi": Double.pi, "π": Double.pi, "e": M_E, "tau": 2 * Double.pi, "τ": 2 * Double.pi]
    private static let functions: [String: ([Double]) throws -> Double] = [
        "abs": { abs($0[0]) }, "round": { $0[0].rounded() }, "floor": { floor($0[0]) },
        "ceil": { ceil($0[0]) }, "trunc": { Double(Int($0[0])) }, "sqrt": { sqrt($0[0]) },
        "cbrt": { Foundation.cbrt($0[0]) }, "pow": { pow($0[0], $0[1]) }, "exp": { exp($0[0]) },
        "log": { log($0[0]) }, "log10": { log10($0[0]) }, "log2": { log2($0[0]) },
        "ln": { log($0[0]) }, "sin": { sin($0[0]) }, "cos": { cos($0[0]) },
        "tan": { tan($0[0]) }, "asin": { asin($0[0]) }, "acos": { acos($0[0]) },
        "atan": { atan($0[0]) }, "atan2": { atan2($0[0], $0[1]) }, "sinh": { sinh($0[0]) },
        "cosh": { cosh($0[0]) }, "tanh": { tanh($0[0]) }, "degrees": { $0[0] * 180 / Double.pi },
        "deg": { $0[0] * 180 / Double.pi }, "radians": { $0[0] * Double.pi / 180 },
        "rad": { $0[0] * Double.pi / 180 }, "min": { $0.min() ?? 0 }, "max": { $0.max() ?? 0 },
        "sum": { $0.reduce(0, +) }, "factorial": { (1...max(1, Int($0[0]))).reduce(1.0) { $0 * Double($1) } },
        "gcd": { Double(gcd(Int($0[0]), Int($0[1]))) }, "lcm": { Double(lcm(Int($0[0]), Int($0[1]))) }
    ]
}

private func gcd(_ left: Int, _ right: Int) -> Int {
    var left = abs(left)
    var right = abs(right)
    while right != 0 {
        let remainder = left % right
        left = right
        right = remainder
    }
    return left
}

private func lcm(_ left: Int, _ right: Int) -> Int {
    abs(left * right) / max(gcd(left, right), 1)
}
