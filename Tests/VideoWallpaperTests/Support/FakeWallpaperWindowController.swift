import AVFoundation
import Foundation
@testable import VideoWallpaper

@MainActor
final class FakeWallpaperWindowController: WallpaperWindowControlling {

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?
    var onPlaybackFailed: (() -> Void)?

    private(set) var loadCallCount = 0
    private(set) var loadedURLs: [URL] = []
    private(set) var resumeCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearVideoCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var applyDimLevelCallCount = 0
    private(set) var applyVideoGravityCallCount = 0

    func load(
        videoURL url: URL,
        timeRange: CMTimeRange?,
        itemID: PlaylistItem.ID?,
        token: RotationEngine<PlaylistItem>.PlaybackToken?
    ) {
        loadCallCount += 1
        loadedURLs.append(url)
    }

    func clearVideo() {
        clearVideoCallCount += 1
    }

    func invalidate() {
        invalidateCallCount += 1
    }

    func applyDimLevel(_ opacity: CGFloat) {
        applyDimLevelCallCount += 1
    }

    func applyVideoGravity(_ gravity: VideoGravity) {
        applyVideoGravityCallCount += 1
    }

    func pausePlayback() {
        pauseCallCount += 1
    }

    func resumePlayback() {
        resumeCallCount += 1
    }
}
