import Foundation
import Testing
@testable import VideoWallpaper

struct VideoFileTypeTests {

    // MARK: - allowedUTTypes

    @Test func allowedUTTypes_contains_four_entries() {
        #expect(VideoFileType.allowedUTTypes.count == 4)
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

    @Test func png_extension_is_not_supported() {
        #expect(!VideoFileType.isSupported(extension: "png"))
    }

    @Test func empty_extension_is_not_supported() {
        #expect(!VideoFileType.isSupported(extension: ""))
    }

    // MARK: - gif

    @Test func gifIsSupported() {
        #expect(VideoFileType.isSupported(extension: "gif"))
        #expect(VideoFileType.isSupported(extension: "GIF"))
    }

    @Test func gifIsDetected() {
        #expect(VideoFileType.isGIF(extension: "gif"))
        #expect(VideoFileType.isGIF(extension: "GIF"))
        #expect(!VideoFileType.isGIF(extension: "mp4"))
    }

    @Test func allowedUTTypesIncludesGIF() {
        #expect(VideoFileType.allowedUTTypes.contains(.gif))
    }
}
