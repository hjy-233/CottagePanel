import Foundation

enum NativeCottageLogsBuiltIn {
    static func results(query: String) -> [CustomActionResult] {
        let lines = CottageLogStore.recentLines()
        let searchText = query.trimmedSearchText
        let filteredLines = searchText.isEmpty
            ? lines
            : lines.filter { line in
                fuzzySearchMatches(searchText, in: [line])
            }

        var results = [
            nativeResult(
                id: "open-folder",
                title: L10n.text("cottageLogs.openFolder"),
                subtitle: CottageLogStore.logsDirectory.path,
                text: CottageLogStore.logsDirectory.path,
                path: CottageLogStore.logsDirectory.path,
                accessories: [
                    CustomResultAccessory(
                        text: "\(lines.count)",
                        symbolName: "list.bullet.rectangle",
                        style: "secondary"
                    )
                ],
                metadata: [
                    CustomResultMetadata(
                        label: L10n.text("cottageLogs.metadata.file"),
                        value: CottageLogStore.logFileURL.path,
                        type: "code",
                        url: nil
                    )
                ]
            )
        ]

        guard !filteredLines.isEmpty else {
            results.append(nativeResult(
                id: "empty",
                title: L10n.text("cottageLogs.empty.title"),
                subtitle: L10n.text("cottageLogs.empty.subtitle"),
                text: L10n.text("cottageLogs.empty.subtitle"),
                isError: false
            ))
            return results
        }

        results.append(contentsOf: filteredLines.enumerated().map { index, line in
            logLineResult(index: index, line: line)
        })
        return results
    }

    private static func logLineResult(index: Int, line: String) -> CustomActionResult {
        let level = logLevel(in: line)
        return nativeResult(
            id: "line-\(index)",
            title: logTitle(from: line),
            subtitle: line,
            text: line,
            accessories: [
                CustomResultAccessory(
                    text: level,
                    symbolName: level == "ERROR" ? "exclamationmark.triangle" : "info.circle",
                    style: level == "ERROR" ? "red" : "secondary"
                )
            ],
            metadata: [
                CustomResultMetadata(
                    label: L10n.text("cottageLogs.metadata.line"),
                    value: "\(index + 1)",
                    type: "text",
                    url: nil
                ),
                CustomResultMetadata(
                    label: L10n.text("cottageLogs.metadata.file"),
                    value: CottageLogStore.logFileURL.path,
                    type: "code",
                    url: nil
                )
            ],
            isError: level == "ERROR"
        )
    }

    private static func logTitle(from line: String) -> String {
        guard let range = line.range(of: "] ") else {
            return line
        }
        return String(line[range.upperBound...])
    }

    private static func logLevel(in line: String) -> String {
        if line.contains("[ERROR]") {
            return "ERROR"
        }
        return "INFO"
    }
}
