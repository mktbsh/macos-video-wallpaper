import Foundation

enum WallpaperError: Hashable {
    case bookmarkSaveFailed
    case bookmarkResolveFailed
    case playbackFailed
    case unsupportedFileType(String)

    var localizedMessage: String {
        switch self {
        case .bookmarkSaveFailed:
            return String(localized: "error.bookmark_save_failed")
        case .bookmarkResolveFailed:
            return String(localized: "error.bookmark_resolve_failed")
        case .playbackFailed:
            return String(localized: "error.playback_failed")
        case .unsupportedFileType:
            return String(localized: "alert.unsupported_file.title")
        }
    }
}
