import Foundation

final class CustomActionOutputBuffer {
    private var buffer = ""
    private var totalBytes = 0
    private var isClosed = false
    private let lock = NSLock()

    func append(_ chunk: String) -> CustomActionOutputAppendResult {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !isClosed else {
            return CustomActionOutputAppendResult(lines: [], error: nil)
        }

        totalBytes += chunk.utf8.count
        if totalBytes > CustomActionRunner.maxOutputBytes {
            return close(with: L10n.text("custom.result.outputTooLarge"))
        }

        buffer.append(chunk)
        let parts = buffer.components(separatedBy: .newlines)
        buffer = parts.last ?? ""
        let lines = parts.dropLast().filter { !$0.isEmpty }
        if lines.contains(where: { $0.utf8.count > CustomActionRunner.maxLineBytes })
            || buffer.utf8.count > CustomActionRunner.maxLineBytes {
            return close(with: L10n.text("custom.result.lineTooLarge"))
        }
        return CustomActionOutputAppendResult(lines: lines, error: nil)
    }

    func flush() -> CustomActionOutputFlushResult {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !isClosed else {
            return CustomActionOutputFlushResult(line: nil, error: nil)
        }

        let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        if remaining.utf8.count > CustomActionRunner.maxLineBytes {
            return CustomActionOutputFlushResult(line: nil, error: L10n.text("custom.result.lineTooLarge"))
        }
        return CustomActionOutputFlushResult(line: remaining.isEmpty ? nil : remaining, error: nil)
    }

    private func close(with error: String) -> CustomActionOutputAppendResult {
        isClosed = true
        buffer = ""
        return CustomActionOutputAppendResult(lines: [], error: error)
    }
}

struct CustomActionOutputAppendResult {
    let lines: [String]
    let error: String?
}

struct CustomActionOutputFlushResult {
    let line: String?
    let error: String?
}
