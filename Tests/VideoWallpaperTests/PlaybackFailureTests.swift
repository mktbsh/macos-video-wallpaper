import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct PlaybackFailureTests {

    @Test func playback_failure_fires_callback() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failedDisplayIDs: [DisplayIdentifier] = []
        context.controller.onPlaybackFailed = { failedDisplayIDs.append($0) }

        context.controller.load(videoURL: wallpaperWindowTestURL("failure-test.mov"))
        let target = try #require(context.driver.observationTargets.first) as? FakePlaybackObservationTarget
        let fakeTarget = try #require(target)
        context.observer.emitPlaybackFailed(for: fakeTarget)

        #expect(failedDisplayIDs.count == 1)
        #expect(failedDisplayIDs.first == DisplayIdentifier(vendor: 0, model: 0, serial: 0))
    }

    @Test func stale_playback_failure_is_ignored() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failedDisplayIDs: [DisplayIdentifier] = []
        context.controller.onPlaybackFailed = { failedDisplayIDs.append($0) }

        context.controller.load(videoURL: wallpaperWindowTestURL("stale-failure-first.mov"))
        let staleTarget = try #require(
            context.driver.observationTargets.first as? FakePlaybackObservationTarget
        )

        context.controller.load(videoURL: wallpaperWindowTestURL("stale-failure-second.mov"))
        context.observer.emitPlaybackFailed(for: staleTarget)

        #expect(failedDisplayIDs.isEmpty)
    }

    @Test func cleared_playback_failure_is_ignored() throws {
        let context = try WallpaperWindowControllerTestContext()
        var failedDisplayIDs: [DisplayIdentifier] = []
        context.controller.onPlaybackFailed = { failedDisplayIDs.append($0) }

        context.controller.load(videoURL: wallpaperWindowTestURL("cleared-failure.mov"))
        let target = try #require(
            context.driver.observationTargets.first as? FakePlaybackObservationTarget
        )

        context.controller.clearVideo()
        context.observer.emitPlaybackFailed(for: target)

        #expect(failedDisplayIDs.isEmpty)
    }
}
