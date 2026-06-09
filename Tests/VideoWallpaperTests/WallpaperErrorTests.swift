import Foundation
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

    @Test func bookmark_save_failed_message_is_localized_error_bookmark_save_failed() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(
            WallpaperError.bookmarkSaveFailed(displayId).localizedMessage
                == localizedString("error.bookmark_save_failed")
        )
    }

    @Test func bookmark_resolve_failed_message_is_localized_error_bookmark_resolve_failed() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(
            WallpaperError.bookmarkResolveFailed(displayId).localizedMessage
                == localizedString("error.bookmark_resolve_failed")
        )
    }

    @Test func playback_failed_message_is_localized_error_playback_failed() {
        let displayId = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        #expect(
            WallpaperError.playbackFailed(displayId).localizedMessage
                == localizedString("error.playback_failed")
        )
    }

    @Test func unsupported_file_type_message_is_localized_alert_unsupported_file_title() {
        #expect(
            WallpaperError.unsupportedFileType("txt").localizedMessage
                == localizedString("alert.unsupported_file.title")
        )
    }

    private func localizedString(_ key: String) -> String {
        Bundle(for: AppDelegate.self).localizedString(forKey: key, value: nil, table: nil)
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
