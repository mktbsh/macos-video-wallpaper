import Foundation
import Testing
@testable import VideoWallpaper

@MainActor
struct WallpaperErrorTests {

    @Test func bookmark_save_failed_message_is_localized_error_bookmark_save_failed() {
        #expect(
            WallpaperError.bookmarkSaveFailed.localizedMessage
                == localizedString("error.bookmark_save_failed")
        )
    }

    @Test func bookmark_resolve_failed_message_is_localized_error_bookmark_resolve_failed() {
        #expect(
            WallpaperError.bookmarkResolveFailed.localizedMessage
                == localizedString("error.bookmark_resolve_failed")
        )
    }

    @Test func playback_failed_message_is_localized_error_playback_failed() {
        #expect(
            WallpaperError.playbackFailed.localizedMessage
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
        let error1 = WallpaperError.bookmarkSaveFailed
        let error2 = WallpaperError.bookmarkSaveFailed
        let error3 = WallpaperError.playbackFailed

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
