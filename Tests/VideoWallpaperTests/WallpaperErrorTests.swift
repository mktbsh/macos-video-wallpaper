import Testing
@testable import VideoWallpaper

@MainActor
struct WallpaperErrorTests {

    @Test func wallpaper_error_provides_display_identifier_for_display_errors() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)

        #expect(WallpaperError.bookmarkSaveFailed(displayId).displayIdentifier == displayId)
        #expect(WallpaperError.bookmarkResolveFailed(displayId).displayIdentifier == displayId)
        #expect(WallpaperError.playbackFailed(displayId).displayIdentifier == displayId)
    }

    @Test func wallpaper_error_returns_nil_identifier_for_unsupported_file_type() {
        #expect(WallpaperError.unsupportedFileType("txt").displayIdentifier == nil)
    }

    @Test func wallpaper_error_localized_message_is_not_empty() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)

        #expect(!WallpaperError.bookmarkSaveFailed(displayId).localizedMessage.isEmpty)
        #expect(!WallpaperError.bookmarkResolveFailed(displayId).localizedMessage.isEmpty)
        #expect(!WallpaperError.playbackFailed(displayId).localizedMessage.isEmpty)
        #expect(!WallpaperError.unsupportedFileType("txt").localizedMessage.isEmpty)
    }

    @Test func wallpaper_error_conforms_to_hashable() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let error1 = WallpaperError.bookmarkSaveFailed(displayId)
        let error2 = WallpaperError.bookmarkSaveFailed(displayId)
        let error3 = WallpaperError.playbackFailed(displayId)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
