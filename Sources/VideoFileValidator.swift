import Foundation

enum VideoFileValidator {

    private static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func isSupported(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    // MARK: - Bookmark-based persistence

    /// Saves a security-scoped bookmark for the given URL to UserDefaults.
    /// Migrates a legacy path string (key: "videoFilePath") if present.
    static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope) else { return }
        UserDefaults.standard.set(data, forKey: "videoBookmark")
        UserDefaults.standard.removeObject(forKey: "videoFilePath")
    }

    /// Removes the stored security-scoped bookmark from UserDefaults.
    /// The security-scoped access token is independent of the UserDefaults entry;
    /// callers must call stopAccessingSecurityScopedResource() at some point,
    /// but that can happen before or after calling clearBookmark().
    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: "videoBookmark")
    }

    /// Resolves the stored bookmark to a URL, starting security-scoped access.
    /// Falls back to the legacy path key for one-time migration.
    /// Returns nil if no bookmark is stored or the file no longer exists.
    static func resolveBookmarkedURL() -> URL? {
        if let data = UserDefaults.standard.data(forKey: "videoBookmark") {
            return resolve(from: data)
        }
        // One-time migration from legacy path string
        if let path = UserDefaults.standard.string(forKey: "videoFilePath") {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            saveBookmark(for: url)
            return url
        }
        return nil
    }

    private static func resolve(from data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if isStale {
            saveBookmark(for: url)
        }

        _ = url.startAccessingSecurityScopedResource()
        return url
    }
}
