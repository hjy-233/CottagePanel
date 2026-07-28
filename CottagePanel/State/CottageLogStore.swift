// 写入本地安全日志，并按设置控制详细内容
import Foundation

enum CottageLogStore {
    static let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config", isDirectory: true)
        .appendingPathComponent("cottage", isDirectory: true)
        .appendingPathComponent("logs", isDirectory: true)

    static let logFileURL = logsDirectory.appendingPathComponent("cottage.log")

    private static let queue = DispatchQueue(label: "org.dcstudio.CottagePanel.logs")
    private static let stateLock = NSLock()
    private static var detailedLogsState = false
    private static let maxValueLength = 256 * 1024
    private static let redactedValue = "<redacted: enable detailed logs>"
    private static let safeFieldNames = Set([
        "actionID",
        "actionTitle",
        "build",
        "directory",
        "event",
        "executable",
        "exitStatus",
        "menuActionID",
        "menuActionTitle",
        "resultActionID",
        "resultActionTitle",
        "resultCount",
        "stderrBytes",
        "stdoutBytes",
        "status",
        "timeout",
        "type",
        "version"
    ])

    static func info(_ event: String, _ fields: [String: String] = [:]) {
        write(level: "INFO", event: event, fields: fields)
    }

    static func error(_ event: String, _ fields: [String: String] = [:]) {
        write(level: "ERROR", event: event, fields: fields)
    }

    static func setDetailedLogsEnabled(_ isEnabled: Bool) {
        stateLock.lock()
        detailedLogsState = isEnabled
        stateLock.unlock()
    }

    static func recentLines(limit: Int = 500) -> [String] {
        ensureLogFile()
        guard let data = try? Data(contentsOf: logFileURL),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return Array(lines.suffix(limit))
    }

    static func ensureLogFile() {
        do {
            try FileManager.default.createDirectory(
                at: logsDirectory,
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                _ = FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
        } catch {
            NSLog("CottagePanel cannot create log file: \(error.localizedDescription)")
        }
    }

    private static func write(level: String, event: String, fields: [String: String]) {
        queue.async {
            do {
                ensureLogFile()

                let line = formattedLine(level: level, event: event, fields: filteredFields(fields))
                let handle = try FileHandle(forWritingTo: logFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                NSLog("CottagePanel cannot write log: \(error.localizedDescription)")
            }
        }
    }

    private static func formattedLine(level: String, event: String, fields: [String: String]) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fieldText = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(sanitized($0.value))" }
            .joined(separator: " ")

        if fieldText.isEmpty {
            return "\(timestamp) [\(level)] \(event)\n"
        }
        return "\(timestamp) [\(level)] \(event) \(fieldText)\n"
    }

    private static func filteredFields(_ fields: [String: String]) -> [String: String] {
        guard !isDetailedLogsEnabled else {
            return fields
        }

        return fields.reduce(into: [:]) { result, entry in
            result[entry.key] = safeFieldNames.contains(entry.key) ? entry.value : redactedValue
        }
    }

    private static var isDetailedLogsEnabled: Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        return detailedLogsState
    }

    private static func sanitized(_ value: String) -> String {
        let trimmedValue = value.count > maxValueLength
            ? String(value.prefix(maxValueLength)) + "…"
            : value
        return "\""
            + trimmedValue
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\"", with: "\\\"")
            + "\""
    }
}
