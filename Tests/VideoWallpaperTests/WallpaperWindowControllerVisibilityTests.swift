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
