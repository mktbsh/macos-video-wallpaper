import Testing
import Foundation
@testable import VideoWallpaper

@Suite struct VideoFileValidatorTests {

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

    // MARK: - resolveVideoURL(fromPath:)

    @Test func returns_nil_when_path_is_nil() {
        #expect(VideoFileValidator.resolveVideoURL(fromPath: nil) == nil)
    }

    @Test func returns_nil_when_file_does_not_exist() {
        #expect(VideoFileValidator.resolveVideoURL(fromPath: "/nonexistent/path/video.mp4") == nil)
    }

    @Test func returns_url_when_file_exists() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let result = VideoFileValidator.resolveVideoURL(fromPath: url.path)
        #expect(result == url)
    }
}
