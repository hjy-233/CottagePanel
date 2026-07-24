import Foundation

extension CustomActionRunner {
    static func makeProcess(
        customAction: CustomAction,
        query: String,
        result: CustomActionResult?,
        environmentOverrides: [String: String]
    ) -> Process? {
        let definition = customAction.definition
        let process = Process()
        process.currentDirectoryURL = customAction.directoryURL
        process.environment = environment(
            for: customAction,
            query: query,
            result: result,
            environmentOverrides: environmentOverrides
        )

        switch definition.type {
        case .script:
            guard let command = definition.command,
                  let commandURL = customAction.containedFileURL(relativePath: command) else {
                return nil
            }

            if FileManager.default.isExecutableFile(atPath: commandURL.path) {
                process.executableURL = commandURL
            } else {
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = [commandURL.path]
            }
        case .shell:
            guard let command = definition.command else {
                return nil
            }

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
        case .shortcut:
            guard let shortcutName = definition.shortcutName else {
                return nil
            }

            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", shortcutName]
        case .open, .openApp, .url:
            return nil
        }

        return process
    }

    static func environment(
        for customAction: CustomAction,
        query: String,
        result: CustomActionResult?,
        environmentOverrides: [String: String]
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["COTTAGE_QUERY"] = query
        environment["COTTAGE_ACTION_DIR"] = customAction.directoryURL.path
        environment["COTTAGE_LOCALE"] = Locale.preferredLanguages.first ?? "en"
        if let result {
            environment["COTTAGE_RESULT_ID"] = result.id
            environment["COTTAGE_RESULT_TITLE"] = result.title
            environment["COTTAGE_RESULT_SUBTITLE"] = result.subtitle
            environment["COTTAGE_RESULT_TEXT"] = result.text
            environment["COTTAGE_RESULT_URL"] = result.url ?? ""
            environment["COTTAGE_RESULT_PATH"] = result.path ?? ""
            environment["COTTAGE_RESULT_COMMAND"] = result.command ?? ""
        }
        environmentOverrides.forEach { key, value in
            environment[key] = value
        }
        return environment
    }
}
