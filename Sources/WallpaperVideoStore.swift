import Foundation

/// ストアに問い合わせた動画解決の 3 状態。
/// 「未登録」と「登録はあるが解決失敗」を 1 回の呼び出しで区別できる。
enum ResolvedVideo: Equatable {
    case noVideo
    case resolved(URL)
    case resolveFailed
}

/// 全ディスプレイ共通の単一壁紙動画を永続化するグローバルストア。
/// bookmark の生成・解決・stale 再保存・パス正規化は implementation 内の関心事であり、
/// caller には `ResolvedVideo` / `Bool` だけを見せる。
///
/// per-display / legacy の旧キーは一切読み書きしない（クリーンカット）。
protocol WallpaperVideoStoring: AnyObject {
    func resolveVideo() -> ResolvedVideo
    @discardableResult
    func saveVideo(_ url: URL) -> Bool
    func clearVideo()
}

final class WallpaperVideoStore: WallpaperVideoStoring {

    static let bookmarkKey = "wallpaperVideoBookmark"

    private let defaults: UserDefaults
    private let makeBookmarkData: (URL) throws -> Data
    private let resolveBookmarkData: (Data) -> SecurityScopedBookmark.Resolution?

    convenience init(defaults: UserDefaults = .standard) {
        self.init(
            defaults: defaults,
            makeBookmarkData: { try SecurityScopedBookmark.data(for: $0) },
            resolveBookmarkData: { SecurityScopedBookmark.resolve($0) }
        )
    }

    /// テスト専用: codec を差し替えて stale / 生成失敗を deterministic に検証する。
    init(
        defaults: UserDefaults,
        makeBookmarkData: @escaping (URL) throws -> Data,
        resolveBookmarkData: @escaping (Data) -> SecurityScopedBookmark.Resolution?
    ) {
        self.defaults = defaults
        self.makeBookmarkData = makeBookmarkData
        self.resolveBookmarkData = resolveBookmarkData
    }

    func resolveVideo() -> ResolvedVideo {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return .noVideo }
        guard let resolution = resolveBookmarkData(data) else { return .resolveFailed }

        if resolution.isStale {
            // stale な bookmark は解決できたうちに作り直す。失敗しても解決結果は返す。
            if let freshData = try? makeBookmarkData(resolution.url) {
                defaults.set(freshData, forKey: Self.bookmarkKey)
            }
        }
        return .resolved(resolution.url)
    }

    @discardableResult
    func saveVideo(_ url: URL) -> Bool {
        let data: Data
        do {
            data = try makeBookmarkData(url)
        } catch {
            let file = url.lastPathComponent
            Log.security.error(
                "Failed to create wallpaper bookmark for \(file, privacy: .public): \(error.localizedDescription)"
            )
            return false
        }
        defaults.set(data, forKey: Self.bookmarkKey)
        return true
    }

    func clearVideo() {
        defaults.removeObject(forKey: Self.bookmarkKey)
    }
}
