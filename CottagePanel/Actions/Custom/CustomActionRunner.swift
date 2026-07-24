import AppKit
import Foundation

struct CustomActionProcess {
    let id: UUID
    let process: Process
    let timeout: DispatchWorkItem

    func cancel() {
        timeout.cancel()
        guard process.isRunning else {
            return
        }

        process.terminate()
    }
}

struct CustomActionProcessRequest {
    let customAction: CustomAction
    let query: String
    let result: CustomActionResult?
    let inputPayload: CustomActionInputPayload?
    let environmentOverrides: [String: String]
    let timeoutInterval: TimeInterval
    let processID: UUID

    init(
        customAction: CustomAction,
        query: String,
        result: CustomActionResult? = nil,
        inputPayload: CustomActionInputPayload? = nil,
        environmentOverrides: [String: String] = [:],
        timeoutInterval: TimeInterval,
        processID: UUID = UUID()
    ) {
        self.customAction = customAction
        self.query = query
        self.result = result
        self.inputPayload = inputPayload
        self.environmentOverrides = environmentOverrides
        self.timeoutInterval = timeoutInterval
        self.processID = processID
    }
}

struct CustomActionProcessHandlers {
    let onLine: @MainActor (String) -> Void
    let onError: @MainActor (String) -> Void
    let onCompletion: @MainActor (Int32) -> Void
}

enum CustomResultExecutionStatus {
    case opened
    case executed
    case copied
}

enum CustomActionRunner {
    @MainActor private static var retainedProcesses: [CustomActionProcess] = []
    static let maxOutputBytes = 4 * 1024 * 1024
    static let maxLineBytes = 256 * 1024

    @discardableResult
    static func runProcess(
        _ request: CustomActionProcessRequest,
        handlers: CustomActionProcessHandlers
    ) -> CustomActionProcess? {
        guard let process = makeProcess(
            customAction: request.customAction,
            query: request.query,
            result: request.result,
            environmentOverrides: request.environmentOverrides
        ) else {
            return nil
        }

        let pipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        let outputBuffer = CustomActionOutputBuffer()
        let timeout = timeoutWorkItem(process: process, onError: handlers.onError)

        process.standardOutput = pipe
        process.standardError = errorPipe
        process.standardInput = inputPipe
        CustomActionInputWriter.write(request.inputPayload, to: inputPipe)
        installOutputHandler(
            process: process,
            pipe: pipe,
            outputBuffer: outputBuffer,
            onLine: handlers.onLine,
            onError: handlers.onError
        )
        installTerminationHandler(
            process: process,
            pipe: pipe,
            errorPipe: errorPipe,
            context: CustomActionProcessContext(
                outputBuffer: outputBuffer,
                timeout: timeout,
                onLine: handlers.onLine,
                onError: handlers.onError,
                onCompletion: handlers.onCompletion
            )
        )

        return start(
            process: process,
            timeout: timeout,
            timeoutInterval: request.timeoutInterval,
            processID: request.processID
        )
    }

    @MainActor
    static func executeDirect(
        _ customAction: CustomAction,
        query: String = "",
        result: CustomActionResult? = nil,
        inputPayload: CustomActionInputPayload? = nil,
        environmentOverrides: [String: String] = [:]
    ) {
        switch customAction.definition.type {
        case .open, .openApp:
            openPath(customAction.definition.path)
        case .url:
            openURL(customAction.definition.url)
        case .shortcut, .script, .shell:
            let processID = UUID()
            if let process = runProcess(
                CustomActionProcessRequest(
                    customAction: customAction,
                    query: query,
                    result: result,
                    inputPayload: inputPayload,
                    environmentOverrides: environmentOverrides,
                    timeoutInterval: 15,
                    processID: processID
                ),
                handlers: CustomActionProcessHandlers(
                    onLine: { _ in },
                    onError: { _ in },
                    onCompletion: { _ in
                        retainedProcesses.removeAll { $0.id == processID }
                    }
                )
            ) {
                retainedProcesses.append(process)
            }
        }
    }

    private static func installOutputHandler(
        process: Process,
        pipe: Pipe,
        outputBuffer: CustomActionOutputBuffer,
        onLine: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            let result = outputBuffer.append(chunk)
            if let error = result.error {
                process.terminate()
                Task { @MainActor in
                    onError(error)
                }
                return
            }

            result.lines.forEach { line in
                Task { @MainActor in
                    onLine(line)
                }
            }
        }
    }

    private static func installTerminationHandler(
        process: Process,
        pipe: Pipe,
        errorPipe: Pipe,
        context: CustomActionProcessContext
    ) {
        process.terminationHandler = { finishedProcess in
            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            emitRemainingOutput(
                context.outputBuffer,
                onLine: context.onLine,
                onError: context.onError
            )
            emitErrorOutput(errorPipe, onError: context.onError)
            Task { @MainActor in
                context.timeout.cancel()
                context.onCompletion(finishedProcess.terminationStatus)
            }
        }
    }

    private static func emitRemainingOutput(
        _ outputBuffer: CustomActionOutputBuffer,
        onLine: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        let flushResult = outputBuffer.flush()
        if let error = flushResult.error {
            Task { @MainActor in
                onError(error)
            }
            return
        }

        guard let remaining = flushResult.line else {
            return
        }

        Task { @MainActor in
            onLine(remaining)
        }
    }

    private static func emitErrorOutput(
        _ errorPipe: Pipe,
        onError: @escaping @MainActor (String) -> Void
    ) {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard !errorData.isEmpty, let errorText = String(data: errorData, encoding: .utf8) else {
            return
        }

        Task { @MainActor in
            onError(errorText)
        }
    }

    private static func timeoutWorkItem(
        process: Process,
        onError: @escaping @MainActor (String) -> Void
    ) -> DispatchWorkItem {
        DispatchWorkItem {
            guard process.isRunning else {
                return
            }

            process.terminate()
            Task { @MainActor in
                onError(L10n.text("custom.result.timeout"))
            }
        }
    }

    private static func start(
        process: Process,
        timeout: DispatchWorkItem,
        timeoutInterval: TimeInterval,
        processID: UUID
    ) -> CustomActionProcess? {
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutInterval, execute: timeout)
            return CustomActionProcess(id: processID, process: process, timeout: timeout)
        } catch {
            NSLog("CottagePanel cannot run custom action: \(error.localizedDescription)")
            return nil
        }
    }
}

private struct CustomActionProcessContext {
    let outputBuffer: CustomActionOutputBuffer
    let timeout: DispatchWorkItem
    let onLine: @MainActor (String) -> Void
    let onError: @MainActor (String) -> Void
    let onCompletion: @MainActor (Int32) -> Void
}
