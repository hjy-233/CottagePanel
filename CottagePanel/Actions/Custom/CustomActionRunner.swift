// 运行自定义 action 并管理进程生命周期与输出
import AppKit
import Foundation

// MARK: - Process Model

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

// MARK: - Runner

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
            CottageLogStore.error("customAction.process.invalid", [
                "actionID": request.customAction.definition.id,
                "actionTitle": request.customAction.definition.title,
                "type": request.customAction.definition.type.rawValue
            ])
            return nil
        }

        let logContext = makeLogContext(for: request, process: process)
        let timeout = installProcessIO(
            process: process,
            logContext: logContext,
            inputPayload: request.inputPayload,
            handlers: handlers
        )
        return start(
            process: process,
            timeout: timeout,
            timeoutInterval: request.timeoutInterval,
            processID: request.processID,
            logContext: logContext
        )
    }

    private static func installProcessIO(
        process: Process,
        logContext: CustomActionLogContext,
        inputPayload: CustomActionInputPayload?,
        handlers: CustomActionProcessHandlers
    ) -> DispatchWorkItem {
        let pipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        let outputBuffer = CustomActionOutputBuffer()
        let timeout = timeoutWorkItem(process: process, logContext: logContext, onError: handlers.onError)

        process.standardOutput = pipe
        process.standardError = errorPipe
        process.standardInput = inputPipe
        CustomActionInputWriter.write(inputPayload, to: inputPipe)
        installOutputHandler(
            process: process,
            pipe: pipe,
            context: CustomActionOutputContext(
                outputBuffer: outputBuffer,
                logContext: logContext,
                onLine: handlers.onLine,
                onError: handlers.onError
            )
        )
        installTerminationHandler(
            process: process,
            pipe: pipe,
            errorPipe: errorPipe,
            context: CustomActionProcessContext(
                outputBuffer: outputBuffer,
                timeout: timeout,
                logContext: logContext,
                onLine: handlers.onLine,
                onError: handlers.onError,
                onCompletion: handlers.onCompletion
            )
        )
        return timeout
    }

    private static func makeLogContext(
        for request: CustomActionProcessRequest,
        process: Process
    ) -> CustomActionLogContext {
        CustomActionLogContext(
            actionID: request.customAction.definition.id,
            title: request.customAction.definition.title,
            type: request.customAction.definition.type.rawValue,
            query: request.query,
            directory: request.customAction.directoryURL.path,
            executable: process.executableURL?.path ?? "",
            arguments: process.arguments?.joined(separator: " ") ?? ""
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
}

private extension CustomActionRunner {
    private static func installOutputHandler(
        process: Process,
        pipe: Pipe,
        context: CustomActionOutputContext
    ) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            let result = context.outputBuffer.append(chunk)
            if let error = result.error {
                CottageLogStore.error("customAction.output.error", context.logContext.fields([
                    "error": error
                ]))
                process.terminate()
                Task { @MainActor in
                    context.onError(error)
                }
                return
            }

            result.lines.forEach { line in
                CottageLogStore.info("customAction.stdout", context.logContext.fields(["line": line]))
                Task { @MainActor in
                    context.onLine(line)
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
                logContext: context.logContext,
                onLine: context.onLine,
                onError: context.onError
            )
            emitErrorOutput(errorPipe, logContext: context.logContext, onError: context.onError)
            Task { @MainActor in
                context.timeout.cancel()
                CottageLogStore.info("customAction.process.finish", context.logContext.fields([
                    "status": "\(finishedProcess.terminationStatus)"
                ]))
                context.onCompletion(finishedProcess.terminationStatus)
            }
        }
    }

    private static func emitRemainingOutput(
        _ outputBuffer: CustomActionOutputBuffer,
        logContext: CustomActionLogContext,
        onLine: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        let flushResult = outputBuffer.flush()
        if let error = flushResult.error {
            CottageLogStore.error("customAction.output.error", logContext.fields([
                "error": error
            ]))
            Task { @MainActor in
                onError(error)
            }
            return
        }

        guard let remaining = flushResult.line else {
            return
        }

        CottageLogStore.info("customAction.stdout", logContext.fields(["line": remaining]))
        Task { @MainActor in
            onLine(remaining)
        }
    }

    private static func emitErrorOutput(
        _ errorPipe: Pipe,
        logContext: CustomActionLogContext,
        onError: @escaping @MainActor (String) -> Void
    ) {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard !errorData.isEmpty, let errorText = String(data: errorData, encoding: .utf8) else {
            return
        }

        CottageLogStore.error("customAction.stderr", logContext.fields([
            "text": errorText
        ]))
        Task { @MainActor in
            onError(errorText)
        }
    }

    private static func timeoutWorkItem(
        process: Process,
        logContext: CustomActionLogContext,
        onError: @escaping @MainActor (String) -> Void
    ) -> DispatchWorkItem {
        DispatchWorkItem {
            guard process.isRunning else {
                return
            }

            process.terminate()
            CottageLogStore.error("customAction.timeout", logContext.fields())
            Task { @MainActor in
                onError(L10n.text("custom.result.timeout"))
            }
        }
    }

    private static func start(
        process: Process,
        timeout: DispatchWorkItem,
        timeoutInterval: TimeInterval,
        processID: UUID,
        logContext: CustomActionLogContext
    ) -> CustomActionProcess? {
        do {
            CottageLogStore.info("customAction.process.start", logContext.fields([
                "timeout": "\(timeoutInterval)"
            ]))
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutInterval, execute: timeout)
            return CustomActionProcess(id: processID, process: process, timeout: timeout)
        } catch {
            CottageLogStore.error("customAction.process.startFailed", logContext.fields([
                "error": error.localizedDescription
            ]))
            NSLog("CottagePanel cannot run custom action: \(error.localizedDescription)")
            return nil
        }
    }
}

private struct CustomActionProcessContext {
    let outputBuffer: CustomActionOutputBuffer
    let timeout: DispatchWorkItem
    let logContext: CustomActionLogContext
    let onLine: @MainActor (String) -> Void
    let onError: @MainActor (String) -> Void
    let onCompletion: @MainActor (Int32) -> Void
}

private struct CustomActionOutputContext {
    let outputBuffer: CustomActionOutputBuffer
    let logContext: CustomActionLogContext
    let onLine: @MainActor (String) -> Void
    let onError: @MainActor (String) -> Void
}

private struct CustomActionLogContext: Sendable {
    let actionID: String
    let title: String
    let type: String
    let query: String
    let directory: String
    let executable: String
    let arguments: String

    func fields(_ extraFields: [String: String] = [:]) -> [String: String] {
        var fields = [
            "actionID": actionID,
            "actionTitle": title,
            "type": type,
            "query": query,
            "directory": directory,
            "executable": executable,
            "arguments": arguments
        ]
        extraFields.forEach { key, value in
            fields[key] = value
        }
        return fields
    }
}
