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
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        // No per-display bookmark → clearVideo is called; battery policy resumes
        let loadAfterSetup = controller.loadCallCount
        let clearAfterSetup = controller.clearVideoCallCount
        let resumeAfterSetup = controller.resumeCallCount
        let invalidateAfterSetup = controller.invalidateCallCount

        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Surviving controller is not touched on screen reconfiguration
        #expect(controller.loadCallCount == loadAfterSetup)
        #expect(controller.clearVideoCallCount == clearAfterSetup)
        #expect(controller.resumeCallCount == resumeAfterSetup)
        #expect(controller.invalidateCallCount == invalidateAfterSetup)
    }
}

@MainActor
private final class FakeWallpaperWindowController: WallpaperWindowControlling {

    var onVideoDropped: ((URL, DisplayIdentifier) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?
    var onPlaybackFailed: ((DisplayIdentifier) -> Void)?

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
