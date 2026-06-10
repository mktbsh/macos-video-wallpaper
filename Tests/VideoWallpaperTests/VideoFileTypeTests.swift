import Foundation
import Testing
@testable import VideoWallpaper

struct VideoFileTypeTests {

    // MARK: - allowedUTTypes

    @Test func allowedUTTypes_contains_three_entries() {
        #expect(VideoFileType.allowedUTTypes.count == 3)
    }

    // MARK: - isSupported(extension:)

    @Test func mp4_extension_is_supported() {
        #expect(VideoFileType.isSupported(extension: "mp4"))
    }

    @Test func MOV_extension_is_supported_case_insensitive() {
        #expect(VideoFileType.isSupported(extension: "MOV"))
    }

    @Test func m4v_extension_is_supported() {
        #expect(VideoFileType.isSupported(extension: "m4v"))
    }

    @Test func gif_extension_is_not_supported() {
        #expect(!VideoFileType.isSupported(extension: "gif"))
    }

    @Test func png_extension_is_not_supported() {
        #expect(!VideoFileType.isSupported(extension: "png"))
    }

    @Test func empty_extension_is_not_supported() {
        #expect(!VideoFileType.isSupported(extension: ""))
    }
}
