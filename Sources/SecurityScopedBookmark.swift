import Foundation

/// Security-scoped bookmark の生成・解決・パス正規化を担う codec。
/// 解決時の stale 再保存は行わない——それは動画ストア（WallpaperVideoStore）の不変条件。
enum SecurityScopedBookmark {

    struct Resolution {
        let url: URL
        let isStale: Bool
    }

    static func data(for url: URL) throws -> Data {
        // アプリの sandbox 権限は user-selected.read-only のため、read-only スコープで
        // bookmark を生成する。`.withSecurityScope` 単体は read-write スコープを取りに行き、
        // 書き込み open が拒否されて NSFileReadUnknownError(256) になる。
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
    }

    /// Resolves bookmark data to a normalized URL.
    /// Returns nil if resolution fails or the file no longer exists.
    static func resolve(_ data: Data) -> Resolution? {
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

        return Resolution(url: normalizedURL, isStale: isStale)
    }

    /// bookmark 解決結果の `/private/` プレフィックス差を吸収する。
    /// 剥がした先に実体があるときだけ剥がす。
    static func normalizeFileURL(_ url: URL) -> URL {
        let path = url.path
        guard path.hasPrefix("/private/") else { return url }

        let normalizedURL = URL(fileURLWithPath: String(path.dropFirst("/private".count)))
        return FileManager.default.fileExists(atPath: normalizedURL.path) ? normalizedURL : url
    }
}
