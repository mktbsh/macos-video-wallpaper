import Foundation

enum VideoFileValidator {

    private static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]
    static let bookmarkKey = "videoBookmark"
    static let legacyPathKey = "videoFilePath"
    static let bookmarkKeyPrefix = "videoBookmark"
    static let displayEnabledKeyPrefix = "displayEnabled"

    static func isSupported(extension ext: String) -> Bool {
        !ext.isEmpty && supportedExtensions.contains(ext.lowercased())
    }

    // MARK: - Bookmark-based persistence

    /// Saves a security-scoped bookmark for the given URL to UserDefaults.
    /// Migrates a legacy path string (key: "videoFilePath") if present.
    static func saveBookmark(for url: URL, defaults: UserDefaults = .standard) {
        let data: Data
        do {
            data = try bookmarkData(for: url)
        } catch {
            let file = url.lastPathComponent
            Log.security.error(
                "Failed to create bookmark for \(file, privacy: .public): \(error.localizedDescription)"
            )
            return
        }
        defaults.set(data, forKey: bookmarkKey)
        defaults.removeObject(forKey: legacyPathKey)
    }

    /// Removes the stored security-scoped bookmark from UserDefaults.
    /// The security-scoped access token is independent of the UserDefaults entry;
    /// callers must call stopAccessingSecurityScopedResource() at some point,
    /// but that can happen before or after calling clearBookmark().
    static func clearBookmark(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: legacyPathKey)
    }

    /// Resolves the stored bookmark to a URL.
    /// Falls back to the legacy path key for one-time migration.
    /// Returns nil if no bookmark is stored or the file no longer exists.
    static func resolveBookmarkedURL(defaults: UserDefaults = .standard) -> URL? {
        if let data = defaults.data(forKey: bookmarkKey) {
            return resolve(from: data, defaults: defaults)
        }
        // One-time migration from legacy path string
        if let path = defaults.string(forKey: legacyPathKey) {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            saveBookmark(for: url, defaults: defaults)
            return url
        }
        return nil
    }

    // MARK: - Per-display bookmark persistence

    /// Saves a security-scoped bookmark for a specific display.
    /// Returns `true` on success, `false` if bookmark creation failed.
    @discardableResult
    static func saveBookmark(
        for url: URL,
        display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let data: Data
        do {
            data = try bookmarkData(for: url)
        } catch {
            let file = url.lastPathComponent
            Log.security.error(
                "Failed to create per-display bookmark for \(file, privacy: .public): \(error.localizedDescription)"
            )
            return false
        }
        defaults.set(data, forKey: display.userDefaultsKey(for: bookmarkKeyPrefix))
        return true
    }

    /// Removes the stored bookmark for a specific display.
    static func clearBookmark(
        display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: display.userDefaultsKey(for: bookmarkKeyPrefix))
    }

    /// Resolves the stored bookmark for a specific display.
    /// Returns nil if no bookmark is stored or the file no longer exists.
    static func resolveBookmarkedURL(
        display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) -> URL? {
        let key = display.userDefaultsKey(for: bookmarkKeyPrefix)
        guard let data = defaults.data(forKey: key) else { return nil }
        return resolve(from: data, defaults: defaults)
    }

    /// Returns whether a bookmark is stored for the given display.
    static func hasBookmark(
        display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.data(forKey: display.userDefaultsKey(for: bookmarkKeyPrefix)) != nil
    }

    // MARK: - Per-display enabled/disabled

    /// Returns whether wallpaper display is enabled for the given display.
    /// Defaults to `true` when no preference has been stored.
    static func isDisplayEnabled(
        _ display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let key = display.userDefaultsKey(for: displayEnabledKeyPrefix)
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    /// Sets the wallpaper display enabled state for the given display.
    static func setDisplayEnabled(
        _ enabled: Bool,
        display: DisplayIdentifier,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: display.userDefaultsKey(for: displayEnabledKeyPrefix))
    }

    // MARK: - Bookmark data

    static func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope)
    }

    static func resolveBookmarkData(_ data: Data) -> URL? {
        resolve(from: data, defaults: nil)
    }

    private static func resolve(from data: Data, defaults: UserDefaults?) -> URL? {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            Log.security.error("Failed to resolve bookmark data: \(error.localizedDescription)")
            return nil
        }

        let normalizedURL = normalizeFileURL(url)
        guard FileManager.default.fileExists(atPath: normalizedURL.path) else { return nil }

        if isStale, let defaults {
            saveBookmark(for: normalizedURL, defaults: defaults)
        }

        return normalizedURL
    }

    private static func normalizeFileURL(_ url: URL) -> URL {
        let path = url.path
        guard path.hasPrefix("/private/") else { return url }

        let normalizedURL = URL(fileURLWithPath: String(path.dropFirst("/private".count)))
        return FileManager.default.fileExists(atPath: normalizedURL.path) ? normalizedURL : url
    }
}
