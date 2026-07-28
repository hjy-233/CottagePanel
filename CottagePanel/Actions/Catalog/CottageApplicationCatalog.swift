// 扫描 macOS 应用并转换为 Cottage 动作
import AppKit

extension CottageState {
    func applicationActions() -> [CottageAction] {
        var seenApplicationIDs = Set<String>()

        return applicationURLs().compactMap { url in
            let bundle = Bundle(url: url)
            let englishName = appEnglishName(bundle: bundle, url: url)
            let localizedName = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            let bundleID = bundle?.bundleIdentifier ?? url.path
            guard seenApplicationIDs.insert(bundleID).inserted else {
                return nil
            }

            let title = prefersChinese ? localizedName : englishName

            return CottageAction(
                id: "app.\(bundleID)",
                title: title,
                subtitle: url.path,
                symbolName: "app",
                kind: .application,
                icon: NSWorkspace.shared.icon(forFile: url.path),
                fileURL: url,
                bundleIdentifier: bundle?.bundleIdentifier,
                tags: ["app", L10n.text("tag.application"), englishName, localizedName]
            ) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func applicationURLs() -> [URL] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        let keys: [URLResourceKey] = [.isApplicationKey, .isDirectoryKey]
        return roots.flatMap { root in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return [URL]()
            }

            return enumerator.compactMap { item in
                guard let url = item as? URL, url.pathExtension == "app" else {
                    return nil
                }

                return url
            }
        }
        .uniqued()
    }
}

func appEnglishName(bundle: Bundle?, url: URL) -> String {
    let infoName = bundle?.infoDictionary?["CFBundleName"] as? String
    let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
    return infoName ?? displayName ?? url.deletingPathExtension().lastPathComponent
}

private var prefersChinese: Bool {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen = Set<String>()
        return filter { url in
            seen.insert(url.path).inserted
        }
    }
}
