import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct WallpaperWindowControllerLoadingTests {

    @Test func full_load_replaces_item_and_plays() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("full-load.mov"))

        #expect(context.driver.replaceCurrentItemCallCount == 1)
        #expect(context.driver.playCallCount == 1)
        #expect(context.observer.events == [
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id)
        ])
        #expect(context.accessController.startCount == 1)
    }

    @Test func ranged_load_waits_for_current_seek_completion_before_playing() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(
            videoURL: wallpaperWindowTestURL("ranged-load.mov"),
            timeRange: makeTimeRange(start: 2, end: 5)
        )

        #expect(context.driver.replaceCurrentItemCallCount == 1)
        #expect(context.driver.playCallCount == 0)

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 1)
    }

    @Test func stale_seek_completion_is_ignored_after_second_load() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(
            videoURL: wallpaperWindowTestURL("first-ranged-load.mov"),
            timeRange: makeTimeRange(start: 1, end: 3)
        )
        context.controller.load(
            videoURL: wallpaperWindowTestURL("second-ranged-load.mov"),
            timeRange: makeTimeRange(start: 4, end: 7)
        )

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 0)

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 1)
    }

    @Test func same_target_and_same_token_is_no_op() throws {
        let context = try WallpaperWindowControllerTestContext()
        let playback = try makePlaybackRequest(url: wallpaperWindowTestURL("same-target.mov"))

        context.controller.load(
            videoURL: playback.item.url,
            timeRange: nil,
            itemID: playback.item.id,
            token: playback.token
        )
        context.controller.load(
            videoURL: playback.item.url,
            timeRange: nil,
            itemID: playback.item.id,
            token: playback.token
        )

        #expect(context.driver.replaceCurrentItemCallCount == 1)
        #expect(context.driver.playCallCount == 1)
    }

    @Test func same_target_with_new_token_reuses_current_item_and_restarts_playback() throws {
        let context = try WallpaperWindowControllerTestContext()
        var store = PlaylistStore(items: [PlaylistItem(url: wallpaperWindowTestURL("same-target-token.mov"))])
        var session = PlaybackSession()
        let firstPlaybackResult = session.beginPlayback(using: &store)
        let firstPlayback = try #require(firstPlaybackResult)
        let secondPlaybackResult = session.beginPlayback(using: &store)
        let secondPlayback = try #require(secondPlaybackResult)

        context.controller.load(
            videoURL: firstPlayback.item.url,
            timeRange: nil,
            itemID: firstPlayback.item.id,
            token: firstPlayback.token
        )
        context.controller.load(
            videoURL: secondPlayback.item.url,
            timeRange: nil,
            itemID: secondPlayback.item.id,
            token: secondPlayback.token
        )

        #expect(context.driver.replaceCurrentItemCallCount == 1)
        #expect(context.accessController.startCount == 1)
        #expect(context.driver.seekCalls.count == 1)
        #expect(context.driver.seekCalls[0].time == .zero)
        #expect(context.driver.playCallCount == 1)
        #expect(context.observer.events == [
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id)
        ])

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 2)
    }

    @Test func old_completion_observation_is_canceled_before_new_one_is_installed() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("first-observed.mov"))
        context.controller.load(videoURL: wallpaperWindowTestURL("second-observed.mov"))

        #expect(context.observer.events == [
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .observe(context.driver.observationTargets[1].id),
            .observeFailure(context.driver.observationTargets[1].id)
        ])
    }
}

@Suite @MainActor
struct WallpaperWindowControllerLifecycleTests {

    @Test func stale_completion_target_is_ignored() throws {
        let context = try WallpaperWindowControllerTestContext()
        var completions: [PlaybackCompletion] = []
        context.controller.onPlaybackFinished = { completions.append($0) }

        let stalePlayback = try makePlaybackRequest(url: wallpaperWindowTestURL("stale-target-first.mov"))
        let currentPlayback = try makePlaybackRequest(url: wallpaperWindowTestURL("stale-target-second.mov"))

        context.controller.load(
            videoURL: stalePlayback.item.url,
            timeRange: nil,
            itemID: stalePlayback.item.id,
            token: stalePlayback.token
        )
        let staleTarget = try #require(context.driver.observationTargets.first)
        context.controller.load(
            videoURL: currentPlayback.item.url,
            timeRange: nil,
            itemID: currentPlayback.item.id,
            token: currentPlayback.token
        )

        context.observer.emitPlaybackFinished(for: staleTarget)
        #expect(completions.isEmpty)

        context.observer.emitPlaybackFinished(for: try #require(context.driver.observationTargets.last))
        #expect(completions == [
            PlaybackCompletion(itemID: currentPlayback.item.id, token: currentPlayback.token)
        ])
        #expect(completions.count == 1)
    }

    @Test func clear_video_ignores_stale_completion_target() throws {
        let context = try WallpaperWindowControllerTestContext()
        var completions: [PlaybackCompletion] = []
        context.controller.onPlaybackFinished = { completions.append($0) }
        let playback = try makePlaybackRequest(url: wallpaperWindowTestURL("clear-stale-target.mov"))

        context.controller.load(
            videoURL: playback.item.url,
            timeRange: nil,
            itemID: playback.item.id,
            token: playback.token
        )
        let target = try #require(context.driver.observationTargets.first)

        context.controller.clearVideo()
        context.observer.emitPlaybackFinished(for: target)

        #expect(completions.isEmpty)
    }

    @Test func reload_stops_previous_scoped_access_once() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("reload-first.mov"))
        let firstHandle = try #require(context.accessController.handles.first)

        context.controller.load(videoURL: wallpaperWindowTestURL("reload-second.mov"))

        #expect(context.accessController.startCount == 2)
        #expect(firstHandle.stopCount == 1)
        #expect(context.accessController.handles[1].stopCount == 0)
    }

    @Test func clear_video_stops_observation_and_scoped_access() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("clear-video.mov"))
        context.controller.clearVideo()

        #expect(context.driver.pauseCallCount == 1)
        #expect(context.driver.clearCurrentItemCallCount == 1)
        #expect(context.observer.events == [
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id)
        ])
        #expect(context.accessController.handles.first?.stopCount == 1)
    }

    @Test func pending_seek_completion_after_clear_does_not_play() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(
            videoURL: wallpaperWindowTestURL("pending-seek-after-clear.mov"),
            timeRange: makeTimeRange(start: 6, end: 9)
        )
        context.controller.clearVideo()
        context.driver.completeSeek(at: 0, finished: true)

        #expect(context.driver.playCallCount == 0)
    }

    @Test func unfinished_seek_completion_does_not_play_current_context() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(
            videoURL: wallpaperWindowTestURL("unfinished-seek.mov"),
            timeRange: makeTimeRange(start: 10, end: 14)
        )
        context.driver.completeSeek(at: 0, finished: false)

        #expect(context.driver.playCallCount == 0)
    }

    @Test func completion_without_playlist_token_loops_playback_from_start() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(videoURL: wallpaperWindowTestURL("loop-video.mov"))

        let target = try #require(context.driver.observationTargets.first)
        context.observer.emitPlaybackFinished(for: target)

        #expect(context.driver.seekCalls.count == 1)
        #expect(context.driver.seekCalls[0].time == .zero)

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 2)
    }

    @Test func completion_without_playlist_token_loops_from_time_range_start() throws {
        let context = try WallpaperWindowControllerTestContext()
        let timeRange = makeTimeRange(start: 3, end: 8)
        context.controller.load(
            videoURL: wallpaperWindowTestURL("loop-ranged.mov"),
            timeRange: timeRange
        )
        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 1)

        let target = try #require(context.driver.observationTargets.first)
        context.observer.emitPlaybackFinished(for: target)

        #expect(context.driver.seekCalls.count == 2)
        #expect(context.driver.seekCalls[1].time == timeRange.start)

        context.driver.completeSeek(at: 0, finished: true)
        #expect(context.driver.playCallCount == 2)
    }

    @Test func invalidate_cleans_up_once_and_ignores_pending_seek_completion() throws {
        let context = try WallpaperWindowControllerTestContext()
        context.controller.load(
            videoURL: wallpaperWindowTestURL("invalidate-seek.mov"),
            timeRange: makeTimeRange(start: 8, end: 12)
        )
        context.controller.invalidate()
        context.driver.completeSeek(at: 0, finished: true)

        #expect(context.driver.pauseCallCount == 0)
        #expect(context.driver.clearCurrentItemCallCount == 1)
        #expect(context.observer.events == [
            .observe(context.driver.observationTargets[0].id),
            .observeFailure(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id),
            .cancel(context.driver.observationTargets[0].id)
        ])
        #expect(context.accessController.handles.first?.stopCount == 1)
        #expect(context.driver.playCallCount == 0)
    }
}

@MainActor
private func makePlaybackRequest(
    url: URL
) throws -> (item: PlaylistItem, token: RotationEngine<PlaylistItem>.PlaybackToken) {
    var store = PlaylistStore(items: [PlaylistItem(url: url)])
    var session = PlaybackSession()
    let playbackResult = session.beginPlayback(using: &store)
    let playback = try #require(playbackResult)
    return (playback.item, playback.token)
}

private func makeTimeRange(start: Double, end: Double) -> CMTimeRange {
    CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        end: CMTime(seconds: end, preferredTimescale: 600)
    )
}
