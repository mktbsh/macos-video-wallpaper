import Foundation

/// 台帳に問い合わせた動画解決の 3 状態。
/// 「未登録」と「登録はあるが解決失敗」を 1 回の呼び出しで区別できる。
enum ResolvedVideo: Equatable {
    case noVideo
    case resolved(URL)
    case resolveFailed
}

/// 画面ごとの壁紙構成（どの動画を表示するか・有効か）の台帳。
protocol DisplayWallpaperStoring: AnyObject {
    func resolveVideo(for display: DisplayIdentifier) -> ResolvedVideo
    @discardableResult
    func saveVideo(_ url: URL, for display: DisplayIdentifier) -> Bool
    func clearVideo(for display: DisplayIdentifier)
    func isEnabled(_ display: DisplayIdentifier) -> Bool
    func setEnabled(_ enabled: Bool, for display: DisplayIdentifier)
}

/// UserDefaults + security-scoped bookmark による production adapter。
/// bookmark の生成・解決・stale 再保存・パス正規化は implementation 内の関心事であり、
/// caller には ResolvedVideo / Bool だけを見せる。
final class DisplayWallpaperStore: DisplayWallpaperStoring {

    static let bookmarkKey = "videoBookmark"
    static let displayEnabledKeyPrefix = "displayEnabled"

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

    func resolveVideo(for display: DisplayIdentifier) -> ResolvedVideo {
        let key = display.userDefaultsKey(for: Self.bookmarkKey)
        guard let data = defaults.data(forKey: key) else { return .noVideo }
        guard let resolution = resolveBookmarkData(data) else { return .resolveFailed }

        if resolution.isStale {
            // stale な bookmark は解決できたうちに作り直す。失敗しても解決結果は返す。
            if let freshData = try? makeBookmarkData(resolution.url) {
                defaults.set(freshData, forKey: key)
            }
        }
        return .resolved(resolution.url)
    }

    @discardableResult
    func saveVideo(_ url: URL, for display: DisplayIdentifier) -> Bool {
        let data: Data
        do {
            data = try makeBookmarkData(url)
        } catch {
            let file = url.lastPathComponent
            Log.security.error(
                "Failed to create per-display bookmark for \(file, privacy: .public): \(error.localizedDescription)"
            )
            return false
        }
        defaults.set(data, forKey: display.userDefaultsKey(for: Self.bookmarkKey))
        return true
    }

    func clearVideo(for display: DisplayIdentifier) {
        defaults.removeObject(forKey: display.userDefaultsKey(for: Self.bookmarkKey))
    }

    func isEnabled(_ display: DisplayIdentifier) -> Bool {
        let key = display.userDefaultsKey(for: Self.displayEnabledKeyPrefix)
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    func setEnabled(_ enabled: Bool, for display: DisplayIdentifier) {
        defaults.set(enabled, forKey: display.userDefaultsKey(for: Self.displayEnabledKeyPrefix))
    }
}
