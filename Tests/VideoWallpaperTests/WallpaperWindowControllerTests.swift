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
        #expect(context.observer.events == [.observe(context.driver.observationTargets[0].id)])
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
            .cancel(context.driver.observationTargets[0].id),
            .observe(context.driver.observationTargets[0].id)
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
            .cancel(context.driver.observationTargets[0].id),
            .observe(context.driver.observationTargets[1].id)
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
            .cancel(context.driver.observationTargets[0].id)
        ])
        #expect(context.accessController.handles.first?.stopCount == 1)
        #expect(context.driver.playCallCount == 0)
    }
}

@MainActor
struct WallpaperWindowControllerTestContext {
    let window: FakeWindow
    let driver: FakePlayerDriver
    let observer: FakePlaybackCompletionObserver
    let accessController: FakeSecurityScopedAccessController
    let controller: WallpaperWindowController

    init() throws {
        let window = FakeWindow(contentRect: try makeScreen().frame)
        let driver = FakePlayerDriver()
        let observer = FakePlaybackCompletionObserver()
        let accessController = FakeSecurityScopedAccessController()

        self.window = window
        self.driver = driver
        self.observer = observer
        self.accessController = accessController
        controller = WallpaperWindowController(
            window: window,
            displayIdentifier: DisplayIdentifier(vendor: 0, model: 0, serial: 0),
            videoURL: nil,
            driverFactory: FakePlayerDriverFactory(driver: driver),
            playbackCompletionObserver: observer,
            securityScopedAccessController: accessController
        )
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

@MainActor
private func makeScreen() throws -> NSScreen {
    try #require(NSScreen.screens.first)
}

func wallpaperWindowTestURL(_ name: String) -> URL {
    URL(fileURLWithPath: "/tmp/\(name)")
}

private func makeTimeRange(start: Double, end: Double) -> CMTimeRange {
    CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        end: CMTime(seconds: end, preferredTimescale: 600)
    )
}

@MainActor
final class FakePlayerDriverFactory: PlayerDriverFactory {
    let driver: FakePlayerDriver

    init(driver: FakePlayerDriver) {
        self.driver = driver
    }

    func makeDriver() -> PlayerDriver {
        driver
    }
}

@MainActor
final class FakeWindow: NSWindow {
    private(set) var orderFrontCallCount = 0
    private(set) var orderOutCallCount = 0
    private(set) var closeCallCount = 0

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
    }

    override func orderFront(_ sender: Any?) {
        orderFrontCallCount += 1
    }

    override func orderOut(_ sender: Any?) {
        orderOutCallCount += 1
    }

    override func close() {
        closeCallCount += 1
    }
}

@MainActor
final class FakePlayerDriver: PlayerDriver {
    struct ReplacementCall: Equatable {
        let url: URL
        let forwardPlaybackEndTime: CMTime?
    }

    struct SeekCall: Equatable {
        let time: CMTime
        let toleranceBefore: CMTime
        let toleranceAfter: CMTime
    }

    let layer = AVPlayerLayer()

    private(set) var replaceCurrentItemCallCount = 0
    private(set) var replaceCurrentItemCalls: [ReplacementCall] = []
    private(set) var seekCalls: [SeekCall] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearCurrentItemCallCount = 0
    private(set) var observationTargets: [FakePlaybackObservationTarget] = []
    private var pendingSeekCompletions: [(Bool) -> Void] = []

    func replaceCurrentItem(
        with url: URL,
        forwardPlaybackEndTime: CMTime?
    ) -> PlaybackObservationTarget {
        replaceCurrentItemCallCount += 1
        replaceCurrentItemCalls.append(
            ReplacementCall(url: url, forwardPlaybackEndTime: forwardPlaybackEndTime)
        )

        let target = FakePlaybackObservationTarget()
        observationTargets.append(target)
        return target
    }

    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        seekCalls.append(
            SeekCall(
                time: time,
                toleranceBefore: toleranceBefore,
                toleranceAfter: toleranceAfter
            )
        )
        pendingSeekCompletions.append { finished in completion(finished) }
    }

    func play() {
        playCallCount += 1
    }

    func pause() {
        pauseCallCount += 1
    }

    func clearCurrentItem() {
        clearCurrentItemCallCount += 1
    }

    func completeSeek(at index: Int, finished: Bool) {
        let completion = pendingSeekCompletions.remove(at: index)
        completion(finished)
    }
}

@MainActor
final class FakePlaybackObservationTarget: NSObject, PlaybackObservationTarget {
    let id = UUID()
}

@MainActor
final class FakePlaybackCompletionObserver: PlaybackCompletionObserver {
    enum Event: Equatable {
        case observe(UUID)
        case cancel(UUID)
    }

    private final class ObservationToken: NSObject {
        let targetID: UUID

        init(targetID: UUID) {
            self.targetID = targetID
        }
    }

    private var handlers: [UUID: () -> Void] = [:]
    private(set) var events: [Event] = []

    func observePlaybackCompletion(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject {
        let targetID = targetID(for: target)
        handlers[targetID] = { handler() }
        events.append(.observe(targetID))
        return ObservationToken(targetID: targetID)
    }

    func cancelObservation(_ token: AnyObject) {
        guard let token = token as? ObservationToken else { return }
        events.append(.cancel(token.targetID))
        handlers[token.targetID] = nil
    }

    func emitPlaybackFinished(for target: FakePlaybackObservationTarget) {
        handlers[target.id]?()
    }

    private func targetID(for target: PlaybackObservationTarget) -> UUID {
        guard let target = target as? FakePlaybackObservationTarget else {
            fatalError("Unexpected target type: \(type(of: target))")
        }
        return target.id
    }
}

@MainActor
final class FakeSecurityScopedAccessHandle: SecurityScopedAccessHandle {
    private(set) var stopCount = 0

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class FakeSecurityScopedAccessController: SecurityScopedAccessController {
    private(set) var startedURLs: [URL] = []
    private(set) var handles: [FakeSecurityScopedAccessHandle] = []

    func startAccessing(_ url: URL) -> SecurityScopedAccessHandle? {
        startedURLs.append(url)
        let handle = FakeSecurityScopedAccessHandle()
        handles.append(handle)
        return handle
    }

    var startCount: Int {
        startedURLs.count
    }
}
