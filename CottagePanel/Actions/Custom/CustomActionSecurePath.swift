import Foundation

extension CustomAction {
    func containedFileURL(relativePath: String) -> URL? {
        let cleanedPath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPath.isEmpty,
              !cleanedPath.hasPrefix("/"),
              !cleanedPath.split(separator: "/").contains("..") else {
            return nil
        }

        let directoryURL = directoryURL.resolvingSymlinksInPath().standardizedFileURL
        let fileURL = directoryURL
            .appendingPathComponent(cleanedPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path),
              fileURL.path.hasPrefix(directoryURL.path + "/") else {
            return nil
        }

        return fileURL
    }
}
