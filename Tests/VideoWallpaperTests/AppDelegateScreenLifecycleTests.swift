import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) @MainActor
struct AppDelegateScreenLifecycleTests {

    @Test func screen_reconfiguration_keeps_surviving_controller_alive_without_reload() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let playlistStore = PlaylistStore(
            items: [PlaylistItem(url: URL(fileURLWithPath: "/tmp/reconfig.mov"))]
        )
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            playlistStore: playlistStore,
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.loadCallCount == 1)
        #expect(controller.resumeCallCount == 1)
        #expect(controller.pauseCallCount == 0)

        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        #expect(controller.loadCallCount == 1)
        #expect(controller.resumeCallCount == 1)
        #expect(controller.pauseCallCount == 0)
    }
}

@MainActor
private final class FakeWallpaperWindowController: WallpaperWindowControlling {

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?

    private(set) var loadCallCount = 0
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
