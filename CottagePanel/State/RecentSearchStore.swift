// 本地保存最近搜索历史并过滤敏感输入
import Foundation

enum RecentSearchCommand {
    static let prefix = "cottage-recent-search:"
}

enum RecentSearchScope: String, Codable {
    case main
    case custom
}

struct RecentSearchEntry: Codable, Hashable, Identifiable {
    let id: String
    let scope: RecentSearchScope
    let actionID: String?
    let actionTitle: String?
    let query: String
    let accessoryValue: String
    let savedAt: Date
}

enum RecentSearchStore {
    static func entries() -> [RecentSearchEntry] {
        guard let data = try? Data(contentsOf: storeURL),
              let entries = try? decoder.decode([RecentSearchEntry].self, from: data) else {
            return []
        }

        return entries.sorted { $0.savedAt > $1.savedAt }
    }

    static func entry(id: String) -> RecentSearchEntry? {
        entries().first { $0.id == id }
    }

    static func record(_ entry: RecentSearchEntry) {
        ensureDirectory()
        var entries = entries()
        entries.removeAll { existing in
            existing.scope == entry.scope
                && existing.actionID == entry.actionID
                && existing.query == entry.query
                && existing.accessoryValue == entry.accessoryValue
        }
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(50))

        do {
            let data = try encoder.encode(entries)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("CottagePanel cannot write recent searches: \(error.localizedDescription)")
        }
    }

    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
    }

    private static var storeURL: URL {
        configDirectory.appendingPathComponent("recent-searches.json")
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func ensureDirectory() {
        guard !FileManager.default.fileExists(atPath: configDirectory.path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("CottagePanel cannot create config directory: \(error.localizedDescription)")
        }
    }
}
