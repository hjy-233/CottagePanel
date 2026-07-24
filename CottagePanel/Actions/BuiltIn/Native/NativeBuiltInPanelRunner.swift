// swiftlint:disable blanket_disable_command cyclomatic_complexity large_tuple optional_data_string_conversion
import AppKit
import Foundation

@MainActor
extension CottageState {
    func runNativeBuiltInPanelAction(_ customAction: CustomAction) -> Bool {
        guard NativeBuiltInPanelActionID(rawValue: customAction.definition.id) != nil else {
            return false
        }

        guard customAction.definition.input.allowsEmptyQuery || !customQuery.trimmedSearchText.isEmpty else {
            customResults = []
            selectedCustomResultID = nil
            shownCustomResultMenuID = nil
            showStatus(L10n.text("status.noResult"))
            return true
        }

        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        customResultIndex = 0
        isCustomActionRunning = true
        if customAction.definition.trigger == .manual {
            showStatus(L10n.text("status.running"))
        }
        stopCustomProcess()

        let processID = UUID()
        activeCustomProcessID = processID
        let query = customQuery
        let accessoryValue = customAccessoryValue
        customNativeTask = Task { [weak self] in
            let result = await NativeBuiltInPanelRunner.run(
                actionID: customAction.definition.id,
                query: query,
                accessoryValue: accessoryValue
            )
            await MainActor.run {
                guard let self, self.activeCustomProcessID == processID else {
                    return
                }

                self.finishNativePanelRun(result, customAction: customAction)
            }
        }
        return true
    }

    private func finishNativePanelRun(
        _ result: Result<[CustomActionResult], Error>,
        customAction: CustomAction
    ) {
        activeCustomProcessID = nil
        customNativeTask = nil
        isCustomActionRunning = false
        switch result {
        case .success(let results):
            customResults = results
            selectedCustomResultID = results.first?.id
            customResultIndex = results.count
            if customAction.definition.trigger == .manual {
                showStatus(results.isEmpty ? L10n.text("status.noResult") : L10n.text("status.done"))
            }
        case .failure(let error):
            appendCustomError(error.localizedDescription)
            showStatus(L10n.text("status.actionFailed"))
        }
        saveActiveCustomPanelCache()
    }
}

enum NativeBuiltInPanelActionID: String {
    case calculate = "built-in-calculate"
    case colorConverter = "built-in-color-converter"
    case fileSearch = "built-in-file-search"
    case gitViewer = "built-in-git-viewer"
    case hash = "built-in-hash"
    case jsonFormatter = "built-in-json-formatter"
    case processManager = "built-in-process-manager"
    case qrCode = "built-in-qr-code"
    case recentSearch = "built-in-recent-search"
    case translator = "built-in-translator"
    case unixTimeConverter = "built-in-unix-time-converter"
    case webSearch = "built-in-web-search"
    case wordsCount = "built-in-words-count"
}

enum NativeBuiltInPanelRunner {
    static func run(
        actionID: String,
        query: String,
        accessoryValue: String
    ) async -> Result<[CustomActionResult], Error> {
        guard let actionID = NativeBuiltInPanelActionID(rawValue: actionID) else {
            return .success([])
        }

        do {
            let results = try await results(for: actionID, query: query, accessoryValue: accessoryValue)
            return .success(results)
        } catch is CancellationError {
            return .success([])
        } catch {
            return .failure(error)
        }
    }

    private static func results(
        for actionID: NativeBuiltInPanelActionID,
        query: String,
        accessoryValue: String
    ) async throws -> [CustomActionResult] {
        switch actionID {
        case .calculate:
            return try await NativeCalculateBuiltIn.results(query: query)
        case .colorConverter:
            return try NativeColorConverterBuiltIn.results(query: query)
        case .fileSearch:
            return try await NativeFileSearchBuiltIn.results(query: query, scope: accessoryValue)
        case .gitViewer:
            return try await NativeGitViewerBuiltIn.results(query: query)
        case .hash:
            return try await NativeHashBuiltIn.results(query: query)
        case .jsonFormatter:
            return NativeJSONFormatterBuiltIn.results(query: query)
        case .processManager:
            return try await NativeProcessManagerBuiltIn.results(query: query)
        case .qrCode:
            return try NativeQRCodeBuiltIn.results(query: query, codeType: accessoryValue)
        case .recentSearch:
            return NativeRecentSearchBuiltIn.results(query: query)
        case .translator:
            return try await NativeTranslatorBuiltIn.results(query: query, target: accessoryValue)
        case .unixTimeConverter:
            return NativeUnixTimeConverterBuiltIn.results(query: query)
        case .webSearch:
            return NativeWebSearchBuiltIn.results(query: query, engine: accessoryValue)
        case .wordsCount:
            return NativeWordsCountBuiltIn.results(query: query)
        }
    }
}

func nativeResult(
    id: String,
    title: String,
    subtitle: String = "",
    text: String? = nil,
    tags: [String] = [],
    url: String? = nil,
    path: String? = nil,
    previewImagePath: String? = nil,
    command: String? = nil,
    accessories: [CustomResultAccessory] = [],
    metadata: [CustomResultMetadata] = [],
    isError: Bool = false
) -> CustomActionResult {
    CustomActionResult(
        id: id,
        title: title,
        subtitle: subtitle,
        text: text ?? title,
        tags: tags,
        url: url,
        path: path,
        previewImagePath: previewImagePath,
        command: command,
        presentation: nil,
        navigationCommand: nil,
        navigation: nil,
        accessories: accessories,
        metadata: metadata,
        isError: isError
    )
}

func nativeProcessOutput(
    executable: String,
    arguments: [String],
    timeout: TimeInterval = 8
) async throws -> (status: Int32, stdout: Data, stderr: Data) {
    try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let resumeBox = NativeProcessContinuationBox(continuation: continuation)

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { finishedProcess in
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
            resumeBox.resume(.success((finishedProcess.terminationStatus, output, error)))
        }

        do {
            try process.run()
        } catch {
            resumeBox.resume(.failure(error))
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            guard process.isRunning else {
                return
            }
            process.terminate()
            resumeBox.resume(.failure(NativeBuiltInError.message("Action timed out")))
        }
    }
}

private final class NativeProcessContinuationBox: @unchecked Sendable {
    private let continuation: CheckedContinuation<(status: Int32, stdout: Data, stderr: Data), Error>
    private let lock = NSLock()
    private var didResume = false

    init(continuation: CheckedContinuation<(status: Int32, stdout: Data, stderr: Data), Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<(status: Int32, stdout: Data, stderr: Data), Error>) {
        lock.lock()
        let shouldResume = !didResume
        didResume = true
        lock.unlock()

        guard shouldResume else {
            return
        }

        switch result {
        case .success(let output):
            continuation.resume(returning: output)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

func nativeUTF8(_ data: Data) -> String {
    String(decoding: data, as: UTF8.self)
}
