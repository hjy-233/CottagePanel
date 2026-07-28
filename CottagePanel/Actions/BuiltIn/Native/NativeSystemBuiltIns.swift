// swiftlint:disable blanket_disable_command function_body_length line_length
// 实现文件搜索、进程管理、窗口切换等系统内置逻辑
import AppKit
import Foundation

enum NativeFileSearchBuiltIn {
    static func results(query: String, scope: String) async throws -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return []
        }

        var arguments: [String] = []
        if let path = scopePath(scope) {
            arguments.append(contentsOf: ["-onlyin", path.path])
        }
        arguments.append(contentsOf: ["-name", query])
        let output = try await nativeProcessOutput(executable: "/usr/bin/mdfind", arguments: arguments, timeout: 6)
        guard output.status == 0 else {
            return [
                nativeResult(
                    id: "file-search-error",
                    title: "Search failed",
                    subtitle: nativeUTF8(output.stderr),
                    text: nativeUTF8(output.stderr),
                    tags: ["error"],
                    isError: true
                )
            ]
        }

        return nativeUTF8(output.stdout)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(80)
            .enumerated()
            .map { index, path in
                let url = URL(fileURLWithPath: String(path))
                let kind = url.pathExtension.isEmpty ? "file" : url.pathExtension
                return nativeResult(
                    id: "file-\(index)",
                    title: url.lastPathComponent,
                    subtitle: url.deletingLastPathComponent().path,
                    text: url.path,
                    tags: ["file", "search", kind],
                    path: url.path,
                    accessories: [CustomResultAccessory(text: kind, symbolName: "doc", style: "secondary")],
                    metadata: [
                        CustomResultMetadata(label: "Path", value: url.path, type: "code", url: nil),
                        CustomResultMetadata(label: "Folder", value: url.deletingLastPathComponent().path, type: "code", url: nil)
                    ]
                )
            }
    }

    private static func scopePath(_ scope: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch scope {
        case "home":
            return home
        case "desktop":
            return home.appendingPathComponent("Desktop")
        case "downloads":
            return home.appendingPathComponent("Downloads")
        case "documents":
            return home.appendingPathComponent("Documents")
        case "applications":
            return URL(fileURLWithPath: "/Applications")
        default:
            return nil
        }
    }
}

enum NativeProcessManagerBuiltIn {
    static func results(query: String) async throws -> [CustomActionResult] {
        let output = try await nativeProcessOutput(
            executable: "/bin/ps",
            arguments: ["-axo", "pid=,pcpu=,pmem=,comm=,args="],
            timeout: 4
        )
        guard output.status == 0 else {
            return [
                nativeResult(
                    id: "process-error",
                    title: "Process list failed",
                    subtitle: nativeUTF8(output.stderr),
                    text: nativeUTF8(output.stderr),
                    tags: ["error"],
                    isError: true
                )
            ]
        }

        let loweredQuery = query.trimmedSearchText.lowercased()
        let items = nativeUTF8(output.stdout)
            .split(separator: "\n")
            .compactMap { NativeProcessItem(line: String($0)) }
            .filter {
                loweredQuery.isEmpty || $0.haystack.localizedCaseInsensitiveContains(loweredQuery)
            }
            .sorted {
                if $0.cpu == $1.cpu {
                    return $0.memory > $1.memory
                }
                return $0.cpu > $1.cpu
            }
            .prefix(80)
        return items.map(\.result)
    }
}

private struct NativeProcessItem {
    let pid: String
    let cpu: Double
    let memory: Double
    let command: String
    let arguments: String

    init?(line: String) {
        let parts = line.trimmingCharacters(in: .whitespaces).split(maxSplits: 4, omittingEmptySubsequences: true) {
            $0 == " " || $0 == "\t"
        }
        guard parts.count >= 5 else {
            return nil
        }

        pid = String(parts[0])
        cpu = Double(parts[1]) ?? 0
        memory = Double(parts[2]) ?? 0
        command = String(parts[3])
        arguments = String(parts[4])
    }

    var haystack: String {
        "\(pid) \(command) \(arguments)"
    }

    var result: CustomActionResult {
        let name = URL(fileURLWithPath: command).lastPathComponent
        return nativeResult(
            id: "pid-\(pid)",
            title: name.isEmpty ? command : name,
            subtitle: arguments,
            text: pid,
            tags: ["process", "pid", name.lowercased()],
            accessories: [
                CustomResultAccessory(text: "PID \(pid)", symbolName: "number", style: "secondary"),
                CustomResultAccessory(text: String(format: "CPU %.1f%%", cpu), symbolName: "cpu", style: "blue"),
                CustomResultAccessory(text: String(format: "MEM %.1f%%", memory), symbolName: "memorychip", style: "secondary")
            ],
            metadata: [
                CustomResultMetadata(label: "PID", value: pid, type: "code", url: nil),
                CustomResultMetadata(label: "CPU", value: String(format: "%.1f%%", cpu), type: "text", url: nil),
                CustomResultMetadata(label: "Memory", value: String(format: "%.1f%%", memory), type: "text", url: nil),
                CustomResultMetadata(label: "Executable", value: command, type: "code", url: nil),
                CustomResultMetadata(label: "Command", value: arguments, type: "code", url: nil)
            ]
        )
    }
}

enum NativeGitViewerBuiltIn {
    static func results(query: String) async throws -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return [
                nativeResult(
                    id: "help",
                    title: "输入 Git 仓库路径后按 Return",
                    subtitle: "~/project 或 /Users/.../repo",
                    text: "左侧会显示当前分支历史 commits，右侧显示选中 commit 详情。",
                    tags: ["help"]
                )
            ]
        }

        var repoURL = URL(fileURLWithPath: NSString(string: query).expandingTildeInPath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: repoURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            repoURL.deleteLastPathComponent()
        }
        guard FileManager.default.fileExists(atPath: repoURL.appendingPathComponent(".git").path) else {
            return [
                nativeResult(
                    id: "not-git",
                    title: "不是 Git 仓库",
                    subtitle: repoURL.path,
                    text: repoURL.path,
                    tags: ["git", "error"]
                )
            ]
        }

        let branch = try await git(repoURL, ["branch", "--show-current"]).trimmedSearchText
        let records = try await git(repoURL, [
            "log",
            "--date=iso",
            "--pretty=format:%H%x1f%h%x1f%an%x1f%ai%x1f%s%x1f%b%x1e"
        ])
        guard !records.isEmpty else {
            return [nativeResult(id: "empty", title: "No commits", subtitle: repoURL.path, text: repoURL.path)]
        }

        var results: [CustomActionResult] = []
        for record in records.trimmingCharacters(in: CharacterSet(charactersIn: "\u{1e}")).components(separatedBy: "\u{1e}") {
            let parts = record.trimmingCharacters(in: .newlines).components(separatedBy: "\u{1f}")
            guard parts.count >= 6 else {
                continue
            }

            let fullHash = parts[0]
            let shortHash = parts[1]
            let author = parts[2]
            let date = parts[3]
            let subject = parts[4]
            let body = parts[5]
            let detail = (try? await git(repoURL, [
                "show",
                "--stat",
                "--stat-count=120",
                "--format=fuller",
                "--no-ext-diff",
                fullHash
            ])) ?? [fullHash, author, date, subject, body].joined(separator: "\n")
            results.append(nativeResult(
                id: fullHash,
                title: "\(shortHash) · \(subject)",
                subtitle: "\(author) · \(date) · \(branch.isEmpty ? "detached" : branch)",
                text: detail,
                tags: ["git", "commit", branch, author]
            ))
        }
        return results
    }

    private static func git(_ repoURL: URL, _ arguments: [String]) async throws -> String {
        let output = try await nativeProcessOutput(
            executable: "/usr/bin/git",
            arguments: ["-C", repoURL.path] + arguments,
            timeout: 8
        )
        guard output.status == 0 else {
            throw NativeBuiltInError.message(nativeUTF8(output.stderr) + nativeUTF8(output.stdout))
        }
        return nativeUTF8(output.stdout).trimmingCharacters(in: .newlines)
    }
}

enum NativeWebSearchBuiltIn {
    static func results(query: String, engine: String) -> [CustomActionResult] {
        guard !query.trimmedSearchText.isEmpty else {
            return []
        }

        var results: [CustomActionResult] = []
        if let url = urlIfNeeded(query) {
            results.append(nativeResult(
                id: "open-url",
                title: url.absoluteString,
                subtitle: "Open URL",
                text: url.absoluteString,
                tags: ["url", "open"],
                url: url.absoluteString,
                accessories: [CustomResultAccessory(text: "URL", symbolName: "link", style: "blue")],
                metadata: [CustomResultMetadata(label: "URL", value: url.absoluteString, type: "link", url: url.absoluteString)]
            ))
        }

        let selected = engines[engine] ?? engines["google"] ?? ("Google", "https://www.google.com/search?q=%@")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = String(format: selected.1, encoded)
        results.append(nativeResult(
            id: "search-\(engine.isEmpty ? "google" : engine)",
            title: "Search \(selected.0)",
            subtitle: query,
            text: urlString,
            tags: ["web", "search", engine],
            url: urlString,
            accessories: [CustomResultAccessory(text: selected.0, symbolName: "magnifyingglass", style: "secondary")],
            metadata: [
                CustomResultMetadata(label: "Engine", value: selected.0, type: "text", url: nil),
                CustomResultMetadata(label: "Query", value: query, type: "code", url: nil),
                CustomResultMetadata(label: "URL", value: urlString, type: "link", url: urlString)
            ]
        ))
        return results
    }

    private static let engines: [String: (String, String)] = [
        "google": ("Google", "https://www.google.com/search?q=%@"),
        "duckduckgo": ("DuckDuckGo", "https://duckduckgo.com/?q=%@"),
        "bing": ("Bing", "https://www.bing.com/search?q=%@"),
        "brave": ("Brave", "https://search.brave.com/search?q=%@"),
        "github": ("GitHub", "https://github.com/search?q=%@"),
        "wikipedia": ("Wikipedia", "https://en.wikipedia.org/w/index.php?search=%@")
    ]

    private static func urlIfNeeded(_ query: String) -> URL? {
        if let url = URL(string: query), url.scheme != nil {
            return url
        }
        guard query.contains("."), !query.hasPrefix("."), !query.contains(" ") else {
            return nil
        }
        return URL(string: "https://\(query)")
    }
}
