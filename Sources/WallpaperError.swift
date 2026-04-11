import Foundation

enum WallpaperError: Hashable {
    case bookmarkSaveFailed(DisplayIdentifier)
    case bookmarkResolveFailed(DisplayIdentifier)
    case playbackFailed(DisplayIdentifier)
    case unsupportedFileType(String)

    var displayIdentifier: DisplayIdentifier? {
        switch self {
        case .bookmarkSaveFailed(let id),
             .bookmarkResolveFailed(let id),
             .playbackFailed(let id):
            return id
        case .unsupportedFileType:
            return nil
        }
    }

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
