import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct WallpaperWindowControllerLoadingTests {

    @Test func load_creates_driver_loads_url_and_starts_scoped_access() throws {
        let context = try WallpaperWindowControllerTestContext()
        let url = wallpaperWindowTestURL("full-load.mov")

        context.controller.load(videoURL: url)

        #expect(context.factory.requestedURLs == [url])
        #expect(context.driver.loadedURLs == [url])
        #expect(context.accessController.startCount == 1)
    }

    @Test func load_same_url_is_no_op() throws {
        let context = try WallpaperWindowControllerTestContext()
        let url = wallpaperWindowTestURL("same-url.mov")

        context.controller.load(videoURL: url)
        context.controller.load(videoURL: url)

        #expect(context.driver.loadedURLs == [url])
        #expect(context.accessController.startCount == 1)
    }

    @Test func reload_different_url_stops_previous_scoped_access_once() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("reload-first.mov"))
        let firstHandle = try #require(context.accessController.handles.first)

        context.controller.load(videoURL: wallpaperWindowTestURL("reload-second.mov"))

        #expect(context.accessController.startCount == 2)
        #expect(firstHandle.stopCount == 1)
        #expect(context.accessController.handles[1].stopCount == 0)
    }

    @Test func apply_video_gravity_forwards_to_driver() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("gravity.mov"))

        context.controller.applyVideoGravity(.fit)

        #expect(context.driver.appliedGravities.contains(.fit))
    }

    @Test func driver_failure_forwards_to_controller_callback() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failureCount = 0
        context.controller.onPlaybackFailed = { failureCount += 1 }

        context.controller.load(videoURL: wallpaperWindowTestURL("failure.mov"))
        context.driver.emitPlaybackFailed()

        #expect(failureCount == 1)
    }
}

@Suite @MainActor
struct WallpaperWindowControllerLifecycleTests {

    @Test func clear_video_before_any_load_is_no_op() throws {
        let context = try WallpaperWindowControllerTestContext()

        context.controller.clearVideo()

        #expect(context.driver.pauseCallCount == 0)
        #expect(context.driver.clearCallCount == 0)
        #expect(context.window.orderOutCallCount == 0)
    }

    @Test func resume_then_pause_drives_player() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("resume-pause.mov"))

        context.controller.resumePlayback()
        #expect(context.driver.playCallCount == 1)
        #expect(context.window.orderFrontCallCount == 1)

        context.controller.pausePlayback()
        #expect(context.driver.pauseCallCount == 1)
        #expect(context.window.orderOutCallCount == 1)
    }

    @Test func clear_video_tears_down_driver_and_scoped_access() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("clear-video.mov"))

        context.controller.clearVideo()

        #expect(context.driver.pauseCallCount == 1)
        #expect(context.driver.clearCallCount == 1)
        #expect(context.accessController.handles.first?.stopCount == 1)
    }

    @Test func invalidate_closes_window() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("invalidate-close.mov"))

        context.controller.invalidate()

        #expect(context.window.closeCallCount == 1)
        #expect(context.driver.clearCallCount == 1)
        #expect(context.accessController.handles.first?.stopCount == 1)
    }
}
