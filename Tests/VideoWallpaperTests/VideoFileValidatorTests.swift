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

    private let bookmarkKey = "videoBookmark"
    private let legacyPathKey = "videoFilePath"

    private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "VideoFileValidatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
