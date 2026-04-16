import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct VideoFileValidatorTests {

    // MARK: - isSupported(extension:)

    @Test func mp4_extension_is_supported() {
        #expect(VideoFileValidator.isSupported(extension: "mp4"))
    }

    @Test func MOV_extension_is_supported_case_insensitive() {
        #expect(VideoFileValidator.isSupported(extension: "MOV"))
    }

    @Test func m4v_extension_is_supported() {
        #expect(VideoFileValidator.isSupported(extension: "m4v"))
    }

    @Test func gif_extension_is_not_supported() {
        #expect(!VideoFileValidator.isSupported(extension: "gif"))
    }

    @Test func png_extension_is_not_supported() {
        #expect(!VideoFileValidator.isSupported(extension: "png"))
    }

    @Test func empty_extension_is_not_supported() {
        #expect(!VideoFileValidator.isSupported(extension: ""))
    }

    // MARK: - resolveBookmarkedURL()

    @Test func returns_nil_when_no_bookmark_stored() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        #expect(VideoFileValidator.resolveBookmarkedURL(defaults: context.defaults) == nil)
    }

    @Test func returns_nil_when_legacy_path_does_not_exist() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set("/nonexistent/path/video.mp4", forKey: legacyPathKey)
        #expect(VideoFileValidator.resolveBookmarkedURL(defaults: context.defaults) == nil)
    }

    @Test func migrates_legacy_path_to_bookmark_when_file_exists() throws {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        context.defaults.set(url.path, forKey: legacyPathKey)

        let result = VideoFileValidator.resolveBookmarkedURL(defaults: context.defaults)
        #expect(result != nil)
        // Legacy key should be removed after migration
        #expect(context.defaults.string(forKey: legacyPathKey) == nil)
        // Bookmark key should now be set
        #expect(context.defaults.data(forKey: bookmarkKey) != nil)
    }

    // MARK: - clearBookmark()

    @Test func removes_stored_bookmark_when_clearBookmark_called() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set(Data([0x01]), forKey: bookmarkKey)

        VideoFileValidator.clearBookmark(defaults: context.defaults)

        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    @Test func clearBookmark_does_not_crash_when_no_bookmark_stored() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        // Should not crash
        VideoFileValidator.clearBookmark(defaults: context.defaults)
        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    // MARK: - Per-display bookmark: saveBookmark(for:display:)

    @Test func saves_per_display_bookmark() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        let key = display.userDefaultsKey(for: "videoBookmark")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        VideoFileValidator.saveBookmark(for: url, display: display, defaults: context.defaults)

        #expect(context.defaults.data(forKey: key) != nil)
    }

    @Test func per_display_bookmark_does_not_affect_global_bookmark() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        VideoFileValidator.saveBookmark(for: url, display: display, defaults: context.defaults)

        // Global bookmark should remain unset
        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    // MARK: - Per-display bookmark: clearBookmark(display:)

    @Test func clears_per_display_bookmark() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 10, model: 20, serial: 30)
        let key = display.userDefaultsKey(for: "videoBookmark")

        context.defaults.set(Data([0x01, 0x02]), forKey: key)

        VideoFileValidator.clearBookmark(display: display, defaults: context.defaults)

        #expect(context.defaults.data(forKey: key) == nil)
    }

    @Test func clear_per_display_does_not_affect_other_displays() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let display2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)
        let key1 = display1.userDefaultsKey(for: "videoBookmark")
        let key2 = display2.userDefaultsKey(for: "videoBookmark")

        context.defaults.set(Data([0x01]), forKey: key1)
        context.defaults.set(Data([0x02]), forKey: key2)

        VideoFileValidator.clearBookmark(display: display1, defaults: context.defaults)

        #expect(context.defaults.data(forKey: key1) == nil)
        #expect(context.defaults.data(forKey: key2) != nil)
    }

    @Test func clear_per_display_does_not_crash_when_no_bookmark() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)

        // Should not crash
        VideoFileValidator.clearBookmark(display: display, defaults: context.defaults)

        let key = display.userDefaultsKey(for: "videoBookmark")
        #expect(context.defaults.data(forKey: key) == nil)
    }

    // MARK: - Per-display bookmark: resolveBookmarkedURL(display:)

    @Test func resolve_per_display_returns_nil_when_no_bookmark() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(
            VideoFileValidator.resolveBookmarkedURL(display: display, defaults: context.defaults)
                == nil
        )
    }

    // MARK: - hasBookmark(display:)

    @Test func hasBookmark_returns_false_when_no_bookmark_stored() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(!VideoFileValidator.hasBookmark(display: display, defaults: context.defaults))
    }

    @Test func hasBookmark_returns_true_when_bookmark_is_stored() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let key = display.userDefaultsKey(for: "videoBookmark")
        context.defaults.set(Data([0x01]), forKey: key)

        #expect(VideoFileValidator.hasBookmark(display: display, defaults: context.defaults))
    }

    @Test func hasBookmark_returns_false_after_clear() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let key = display.userDefaultsKey(for: "videoBookmark")
        context.defaults.set(Data([0x01]), forKey: key)

        VideoFileValidator.clearBookmark(display: display, defaults: context.defaults)

        #expect(!VideoFileValidator.hasBookmark(display: display, defaults: context.defaults))
    }

    // MARK: - isDisplayEnabled

    @Test func display_enabled_defaults_to_true() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(VideoFileValidator.isDisplayEnabled(display, defaults: context.defaults))
    }

    @Test func display_enabled_returns_false_when_set_to_false() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        VideoFileValidator.setDisplayEnabled(false, display: display, defaults: context.defaults)

        #expect(!VideoFileValidator.isDisplayEnabled(display, defaults: context.defaults))
    }

    @Test func display_enabled_returns_true_when_set_to_true() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        VideoFileValidator.setDisplayEnabled(false, display: display, defaults: context.defaults)
        VideoFileValidator.setDisplayEnabled(true, display: display, defaults: context.defaults)

        #expect(VideoFileValidator.isDisplayEnabled(display, defaults: context.defaults))
    }

    @Test func display_enabled_is_independent_per_display() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let display1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let display2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)

        VideoFileValidator.setDisplayEnabled(false, display: display1, defaults: context.defaults)

        #expect(!VideoFileValidator.isDisplayEnabled(display1, defaults: context.defaults))
        #expect(VideoFileValidator.isDisplayEnabled(display2, defaults: context.defaults))
    }

    // MARK: - Helpers

    private let bookmarkKey = "videoBookmark"
    private let legacyPathKey = "videoFilePath"

    private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "VideoFileValidatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
