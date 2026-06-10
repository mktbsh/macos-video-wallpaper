import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct DisplayWallpaperStoreTests {

    // MARK: - resolveVideo(for:)

    @Test func resolve_returns_noVideo_when_nothing_saved() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(context.store.resolveVideo(for: display) == .noVideo)
    }

    @Test func resolve_returns_resolved_url_after_save() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display = DisplayIdentifier(vendor: 10, model: 20, serial: 30)
        #expect(context.store.saveVideo(url, for: display))

        let result = context.store.resolveVideo(for: display)
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

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(context.store.saveVideo(url, for: display))
        try FileManager.default.removeItem(at: url)

        #expect(context.store.resolveVideo(for: display) == .resolveFailed)
    }

    @Test func resolve_resaves_bookmark_when_stale() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let key = display.userDefaultsKey(for: DisplayWallpaperStore.bookmarkKey)
        context.defaults.set(Data("stale-payload".utf8), forKey: key)

        let store = DisplayWallpaperStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in Data("fresh-payload".utf8) },
            resolveBookmarkData: { _ in
                SecurityScopedBookmark.Resolution(url: url, isStale: true)
            }
        )

        #expect(store.resolveVideo(for: display) == .resolved(url))
        #expect(context.defaults.data(forKey: key) == Data("fresh-payload".utf8))
    }

    @Test func resolve_keeps_existing_payload_when_not_stale() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let key = display.userDefaultsKey(for: DisplayWallpaperStore.bookmarkKey)
        context.defaults.set(Data("original".utf8), forKey: key)

        let store = DisplayWallpaperStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in Data("should-not-be-written".utf8) },
            resolveBookmarkData: { _ in
                SecurityScopedBookmark.Resolution(url: url, isStale: false)
            }
        )

        #expect(store.resolveVideo(for: display) == .resolved(url))
        #expect(context.defaults.data(forKey: key) == Data("original".utf8))
    }

    // MARK: - saveVideo(_:for:)

    @Test func save_returns_false_when_bookmark_creation_fails() {
        let context = TestContext()
        defer { context.cleanup() }

        struct CodecError: Error {}
        let store = DisplayWallpaperStore(
            defaults: context.defaults,
            makeBookmarkData: { _ in throw CodecError() },
            resolveBookmarkData: { _ in nil }
        )

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(!store.saveVideo(URL(fileURLWithPath: "/nonexistent.mp4"), for: display))

        let key = display.userDefaultsKey(for: DisplayWallpaperStore.bookmarkKey)
        #expect(context.defaults.data(forKey: key) == nil)
    }

    @Test func save_does_not_affect_other_displays() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let display2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)
        #expect(context.store.saveVideo(url, for: display1))

        #expect(context.store.resolveVideo(for: display2) == .noVideo)
    }

    // MARK: - clearVideo(for:)

    @Test func clear_removes_saved_video() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display = DisplayIdentifier(vendor: 10, model: 20, serial: 30)
        #expect(context.store.saveVideo(url, for: display))

        context.store.clearVideo(for: display)

        #expect(context.store.resolveVideo(for: display) == .noVideo)
    }

    @Test func clear_does_not_affect_other_displays() {
        let context = TestContext()
        defer { context.cleanup() }

        let display1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let display2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)
        let key1 = display1.userDefaultsKey(for: DisplayWallpaperStore.bookmarkKey)
        let key2 = display2.userDefaultsKey(for: DisplayWallpaperStore.bookmarkKey)
        context.defaults.set(Data([0x01]), forKey: key1)
        context.defaults.set(Data([0x02]), forKey: key2)

        context.store.clearVideo(for: display1)

        #expect(context.defaults.data(forKey: key1) == nil)
        #expect(context.defaults.data(forKey: key2) != nil)
    }

    @Test func clear_does_not_crash_when_nothing_saved() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        context.store.clearVideo(for: display)
        #expect(context.store.resolveVideo(for: display) == .noVideo)
    }

    // MARK: - isEnabled / setEnabled

    @Test func enabled_defaults_to_true() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(context.store.isEnabled(display))
    }

    @Test func enabled_returns_false_after_set_false() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        context.store.setEnabled(false, for: display)

        #expect(!context.store.isEnabled(display))
    }

    @Test func enabled_returns_true_after_set_back_to_true() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        context.store.setEnabled(false, for: display)
        context.store.setEnabled(true, for: display)

        #expect(context.store.isEnabled(display))
    }

    @Test func enabled_is_independent_per_display() {
        let context = TestContext()
        defer { context.cleanup() }

        let display1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let display2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)
        context.store.setEnabled(false, for: display1)

        #expect(!context.store.isEnabled(display1))
        #expect(context.store.isEnabled(display2))
    }

    // MARK: - UserDefaults key 互換（既存データを壊さない）

    @Test func bookmark_key_format_is_backward_compatible() {
        let context = TestContext()
        defer { context.cleanup() }
        let url = context.makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let display = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        #expect(context.store.saveVideo(url, for: display))

        let key = display.userDefaultsKey(for: "videoBookmark")
        #expect(context.defaults.data(forKey: key) != nil)
    }

    @Test func enabled_key_format_is_backward_compatible() {
        let context = TestContext()
        defer { context.cleanup() }

        let display = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        context.store.setEnabled(false, for: display)

        let key = display.userDefaultsKey(for: "displayEnabled")
        #expect(context.defaults.object(forKey: key) != nil)
        #expect(!context.defaults.bool(forKey: key))
    }

    // MARK: - Helpers

    private struct TestContext {
        let suiteName = "DisplayWallpaperStoreTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let store: DisplayWallpaperStore

        init() {
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            self.defaults = defaults
            self.store = DisplayWallpaperStore(defaults: defaults)
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }

        func makeTempFile() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("store_\(UUID().uuidString).mp4")
            FileManager.default.createFile(atPath: url.path, contents: Data())
            return url
        }
    }
}
