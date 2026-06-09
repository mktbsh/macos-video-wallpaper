import AVFoundation
import CoreGraphics
import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct WallpaperWindowControllerVisibilityTests {

    @Test func window_is_configured_for_desktop_playback_and_drag_and_drop() throws {
        let context = try WallpaperWindowControllerTestContext()

        #expect(
            context.window.level.rawValue
                == Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        #expect(context.window.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(context.window.collectionBehavior.contains(.stationary))
        #expect(context.window.collectionBehavior.contains(.ignoresCycle))
        #expect(context.window.ignoresMouseEvents == false)
        #expect(context.window.isReleasedWhenClosed == false)
    }

    @Test func resume_playback_before_any_load_is_no_op() throws {
        let context = try WallpaperWindowControllerTestContext()

        context.controller.resumePlayback()

        #expect(context.driver.playCallCount == 0)
        #expect(context.window.orderFrontCallCount == 0)
    }

    @Test func pause_playback_before_any_load_is_no_op() throws {
        let context = try WallpaperWindowControllerTestContext()

        context.controller.pausePlayback()

        #expect(context.driver.pauseCallCount == 0)
        #expect(context.window.orderOutCallCount == 0)
    }

    @Test func pause_playback_is_idempotent_when_already_hidden() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("pause-idempotent.mov"))

        context.controller.resumePlayback()
        context.controller.pausePlayback()
        context.controller.pausePlayback()

        #expect(context.driver.pauseCallCount == 1)
        #expect(context.window.orderFrontCallCount == 1)
        #expect(context.window.orderOutCallCount == 1)
    }

    @Test func resume_playback_is_idempotent_when_already_visible() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("resume-idempotent.mov"))

        context.controller.pausePlayback()
        context.controller.resumePlayback()
        context.controller.resumePlayback()

        #expect(context.window.orderFrontCallCount == 1)
        #expect(context.driver.playCallCount == 2)
    }

    @Test func apply_video_gravity_updates_player_layer() throws {
        let context = try WallpaperWindowControllerTestContext()

        context.controller.applyVideoGravity(.fit)
        #expect(context.driver.layer.videoGravity == .resizeAspect)

        context.controller.applyVideoGravity(.stretch)
        #expect(context.driver.layer.videoGravity == .resize)

        context.controller.applyVideoGravity(.fill)
        #expect(context.driver.layer.videoGravity == .resizeAspectFill)
    }

    @Test func apply_dim_level_does_not_crash() throws {
        let context = try WallpaperWindowControllerTestContext()

        context.controller.applyDimLevel(0.0)
        context.controller.applyDimLevel(0.3)
        context.controller.applyDimLevel(0.6)
        // No assertion needed — verifies the method does not crash for all DimLevel opacities
    }

    @Test func resume_playback_while_seek_pending_does_not_double_play() throws {
        let context = try WallpaperWindowControllerTestContext()
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            end: CMTime(seconds: 8, preferredTimescale: 600)
        )
        context.controller.load(
            videoURL: wallpaperWindowTestURL("seek-pending-resume.mov"),
            timeRange: timeRange
        )
        // A seek is now pending; play has not been called yet
        #expect(context.driver.playCallCount == 0)

        // Calling resumePlayback while the seek is in flight should be a no-op
        context.controller.resumePlayback()
        #expect(context.driver.playCallCount == 0)

        // Once the seek completes, play is called exactly once
        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 1)
    }

    @Test func clear_video_is_idempotent_after_first_clear() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("clear-idempotent.mov"))

        context.controller.resumePlayback()
        context.controller.clearVideo()
        context.controller.clearVideo()

        #expect(context.driver.pauseCallCount == 1)
        #expect(context.driver.clearCurrentItemCallCount == 1)
        #expect(context.window.orderFrontCallCount == 1)
        #expect(context.window.orderOutCallCount == 1)
    }
}
