// 把最近搜索记录转换为可执行结果
import Foundation

enum NativeRecentSearchBuiltIn {
    static func results(query: String) -> [CustomActionResult] {
        let searchText = query.trimmedSearchText
        let entries = RecentSearchStore.entries()
        let filteredEntries = searchText.isEmpty
            ? entries
            : entries.filter { entry in
                fuzzySearchMatches(
                    searchText,
                    in: [
                        entry.query,
                        entry.actionTitle ?? "",
                        entry.accessoryValue
                    ]
                )
            }

        guard !filteredEntries.isEmpty else {
            return [
                nativeResult(
                    id: "empty",
                    title: L10n.text("recentSearch.empty.title"),
                    subtitle: L10n.text("recentSearch.empty.subtitle"),
                    text: L10n.text("recentSearch.empty.subtitle"),
                    tags: ["empty"],
                    isError: false
                )
            ]
        }

        return filteredEntries.map(result)
    }

    private static func result(_ entry: RecentSearchEntry) -> CustomActionResult {
        let location = entry.actionTitle ?? L10n.text("recentSearch.mainPanel")
        let accessoryText = entry.scope == .main
            ? L10n.text("recentSearch.main")
            : L10n.text("recentSearch.action")
        return nativeResult(
            id: entry.id,
            title: entry.query,
            subtitle: location,
            text: entry.query,
            command: "\(RecentSearchCommand.prefix)\(entry.id)",
            accessories: [
                CustomResultAccessory(
                    text: accessoryText,
                    symbolName: entry.scope == .main ? "magnifyingglass" : "command",
                    style: "secondary"
                )
            ],
            metadata: [
                CustomResultMetadata(
                    label: L10n.text("recentSearch.metadata.location"),
                    value: location,
                    type: "text",
                    url: nil
                ),
                CustomResultMetadata(
                    label: L10n.text("recentSearch.metadata.query"),
                    value: entry.query,
                    type: "code",
                    url: nil
                ),
                CustomResultMetadata(
                    label: L10n.text("recentSearch.metadata.accessory"),
                    value: entry.accessoryValue.isEmpty ? "-" : entry.accessoryValue,
                    type: "code",
                    url: nil
                ),
                CustomResultMetadata(
                    label: L10n.text("recentSearch.metadata.savedAt"),
                    value: savedAtText(entry.savedAt),
                    type: "text",
                    url: nil
                )
            ]
        )
    }

    private static func savedAtText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
