import CryptoKit
import Foundation

struct CustomActionTrustSummary {
    let fingerprint: String
    let fileCount: Int
    let totalBytes: Int
}

enum CustomActionTrustStore {
    static func isTrusted(_ customAction: CustomAction, summary: CustomActionTrustSummary) -> Bool {
        load()[customAction.definition.id] == summary.fingerprint
    }

    static func trust(_ customAction: CustomAction, summary: CustomActionTrustSummary) {
        var trustedActions = load()
        trustedActions[customAction.definition.id] = summary.fingerprint
        save(trustedActions)
    }

    static func summary(for customAction: CustomAction) -> CustomActionTrustSummary? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: customAction.directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        let files = enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
            .sorted { $0.path < $1.path }

        var hasher = SHA256()
        var totalBytes = 0
        for fileURL in files {
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }

            let relativePath = fileURL.path.replacingOccurrences(
                of: customAction.directoryURL.path + "/",
                with: ""
            )
            hasher.update(data: Data(relativePath.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: data)
            totalBytes += data.count
        }

        let fingerprint = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return CustomActionTrustSummary(
            fingerprint: fingerprint,
            fileCount: files.count,
            totalBytes: totalBytes
        )
    }

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: trustURL),
              let trustedActions = try? decoder.decode([String: String].self, from: data) else {
            return [:]
        }

        return trustedActions
    }

    private static func save(_ trustedActions: [String: String]) {
        ensureDirectory()

        do {
            let data = try encoder.encode(trustedActions)
            try data.write(to: trustURL, options: .atomic)
        } catch {
            NSLog("CottagePanel cannot write trusted-actions.json: \(error.localizedDescription)")
        }
    }

    private static func ensureDirectory() {
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("CottagePanel cannot create config directory: \(error.localizedDescription)")
        }
    }

    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("cottage", isDirectory: true)
    }

    private static var trustURL: URL {
        configDirectory.appendingPathComponent("trusted-actions.json")
    }

    private static let decoder = JSONDecoder()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
