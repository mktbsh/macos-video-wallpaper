import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct WallpaperVideoStoreTests {

    // MARK: - resolveVideo()

    @Test func resolve_returns_noVideo_when_nothing_saved() {
        let context = TestContext()
        defer { context.cleanup() }

        #expect(context.store.resolveVideo() == .noVideo)
    }

    @Test func resolve_returns_resolved_url_after_save() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(context.store.saveVideo(url))

        let result = context.store.resolveVideo()
        guard case .resolved(let resolvedURL) = result else {
            Issue.record("expected .resolved, got \(result)")
            return
        }
        #expect(resolvedURL.lastPathComponent == url.lastPathComponent)
    }

    @Test func resolve_returns_resolveFailed_when_file_deleted_after_save() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()

        #expect(context.store.saveVideo(url))
        try FileManager.default.removeItem(at: url)

        #expect(context.store.resolveVideo() == .resolveFailed)
    }

    @Test func resolve_resaves_bookmark_when_stale() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        context.defaults.set(Data("stale-payload".utf8), forKey: WallpaperVideoStore.bookmarkKey)

        let store = WallpaperVideoStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in Data("fresh-payload".utf8) },
            resolveBookmarkData: { _ in
                SecurityScopedBookmark.Resolution(url: url, isStale: true)
            }
        )

        #expect(store.resolveVideo() == .resolved(url))
        #expect(context.defaults.data(forKey: WallpaperVideoStore.bookmarkKey) == Data("fresh-payload".utf8))
    }

    @Test func resolve_keeps_existing_payload_when_not_stale() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        context.defaults.set(Data("original".utf8), forKey: WallpaperVideoStore.bookmarkKey)

        let store = WallpaperVideoStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in Data("should-not-be-written".utf8) },
            resolveBookmarkData: { _ in
                SecurityScopedBookmark.Resolution(url: url, isStale: false)
            }
        )

        #expect(store.resolveVideo() == .resolved(url))
        #expect(context.defaults.data(forKey: WallpaperVideoStore.bookmarkKey) == Data("original".utf8))
    }

    // MARK: - saveVideo(_:)

    @Test func save_returns_false_when_bookmark_creation_fails() {
        let context = TestContext()
        defer { context.cleanup() }

        struct CodecError: Error {}
        let store = WallpaperVideoStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in throw CodecError() },
            resolveBookmarkData: { _ in nil }
        )

        #expect(!store.saveVideo(URL(fileURLWithPath: "/nonexistent.mp4")))
        #expect(context.defaults.data(forKey: WallpaperVideoStore.bookmarkKey) == nil)
    }

    // MARK: - clearVideo()

    @Test func clear_removes_saved_video() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(context.store.saveVideo(url))
        context.store.clearVideo()

        #expect(context.store.resolveVideo() == .noVideo)
    }

    @Test func clear_does_not_crash_when_nothing_saved() {
        let context = TestContext()
        defer { context.cleanup() }

        context.store.clearVideo()
        #expect(context.store.resolveVideo() == .noVideo)
    }

    // MARK: - UserDefaults key 形式

    @Test func bookmark_key_is_global_dedicated_key() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(context.store.saveVideo(url))
        #expect(context.defaults.data(forKey: "wallpaperVideoBookmark") != nil)
    }

    // MARK: - クリーンカット（旧キーを読まない・消さない）

    @Test func ignores_legacy_and_per_display_keys() {
        let context = TestContext()
        defer { context.cleanup() }

        // 旧仕様で書かれていた可能性のあるキー群を preseed
        context.defaults.set(Data("legacy-global".utf8), forKey: "videoBookmark")
        context.defaults.set("/some/legacy/path.mp4", forKey: "videoFilePath")
        context.defaults.set(Data("per-display".utf8), forKey: "videoBookmark_display_1_2_3")
        context.defaults.set(false, forKey: "displayEnabled_display_1_2_3")

        // グローバルストアはこれらを一切読まない
        #expect(context.store.resolveVideo() == .noVideo)
    }

    @Test func clear_does_not_touch_legacy_keys() {
        let context = TestContext()
        defer { context.cleanup() }

        context.defaults.set(Data("legacy-global".utf8), forKey: "videoBookmark")
        context.defaults.set(Data("per-display".utf8), forKey: "videoBookmark_display_1_2_3")

        context.store.clearVideo()

        #expect(context.defaults.data(forKey: "videoBookmark") != nil)
        #expect(context.defaults.data(forKey: "videoBookmark_display_1_2_3") != nil)
    }

    // MARK: - Helpers

    private struct TestContext {
        let suiteName = "WallpaperVideoStoreTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let store: WallpaperVideoStore

        init() {
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            self.defaults = defaults
            self.store = WallpaperVideoStore(defaults: defaults)
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }

        func makeTempFile() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("wallpaper_video_\(UUID().uuidString).mp4")
            FileManager.default.createFile(atPath: url.path, contents: Data())
            return url
        }
    }
}
