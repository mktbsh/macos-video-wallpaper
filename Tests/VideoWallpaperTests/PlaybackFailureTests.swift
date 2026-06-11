import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct PlaybackFailureTests {

    @Test func playback_failure_fires_callback() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failureCount = 0
        context.controller.onPlaybackFailed = { failureCount += 1 }

        context.controller.load(videoURL: wallpaperWindowTestURL("failure-test.mov"))
        let fakeTarget = try #require(context.driver.observationTargets.first)
        context.observer.emitPlaybackFailed(for: fakeTarget)

        #expect(failureCount == 1)
    }

    @Test func stale_playback_failure_is_ignored() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failureCount = 0
        context.controller.onPlaybackFailed = { failureCount += 1 }

        context.controller.load(videoURL: wallpaperWindowTestURL("stale-failure-first.mov"))
        let staleTarget = try #require(context.driver.observationTargets.first)

        context.controller.load(videoURL: wallpaperWindowTestURL("stale-failure-second.mov"))
        context.observer.emitPlaybackFailed(for: staleTarget)

        #expect(failureCount == 0)
    }

    @Test func cleared_playback_failure_is_ignored() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failureCount = 0
        context.controller.onPlaybackFailed = { failureCount += 1 }

        context.controller.load(videoURL: wallpaperWindowTestURL("cleared-failure.mov"))
        let target = try #require(context.driver.observationTargets.first)

        context.controller.clearVideo()
        context.observer.emitPlaybackFailed(for: target)

        #expect(failureCount == 0)
    }
}
