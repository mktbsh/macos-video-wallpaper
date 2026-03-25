import Testing
import Foundation
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
        UserDefaults.standard.removeObject(forKey: "videoBookmark")
        UserDefaults.standard.removeObject(forKey: "videoFilePath")
        #expect(VideoFileValidator.resolveBookmarkedURL() == nil)
    }

    @Test func returns_nil_when_legacy_path_does_not_exist() {
        UserDefaults.standard.removeObject(forKey: "videoBookmark")
        UserDefaults.standard.set("/nonexistent/path/video.mp4", forKey: "videoFilePath")
        defer { UserDefaults.standard.removeObject(forKey: "videoFilePath") }
        #expect(VideoFileValidator.resolveBookmarkedURL() == nil)
    }

    @Test func migrates_legacy_path_to_bookmark_when_file_exists() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        UserDefaults.standard.removeObject(forKey: "videoBookmark")
        UserDefaults.standard.set(url.path, forKey: "videoFilePath")
        defer {
            UserDefaults.standard.removeObject(forKey: "videoBookmark")
            UserDefaults.standard.removeObject(forKey: "videoFilePath")
        }

        let result = VideoFileValidator.resolveBookmarkedURL()
        #expect(result != nil)
        // Legacy key should be removed after migration
        #expect(UserDefaults.standard.string(forKey: "videoFilePath") == nil)
        // Bookmark key should now be set
        #expect(UserDefaults.standard.data(forKey: "videoBookmark") != nil)
    }

    // MARK: - clearBookmark()

    @Test func clearBookmark_removes_stored_bookmark() {
        UserDefaults.standard.set(Data([0x01]), forKey: "videoBookmark")
        defer { UserDefaults.standard.removeObject(forKey: "videoBookmark") }

        VideoFileValidator.clearBookmark()

        #expect(UserDefaults.standard.data(forKey: "videoBookmark") == nil)
    }

    @Test func clearBookmark_is_noop_when_no_bookmark() {
        UserDefaults.standard.removeObject(forKey: "videoBookmark")
        // Should not crash
        VideoFileValidator.clearBookmark()
        #expect(UserDefaults.standard.data(forKey: "videoBookmark") == nil)
    }
}
