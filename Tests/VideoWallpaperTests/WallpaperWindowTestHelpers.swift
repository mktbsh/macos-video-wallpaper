import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

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
func makeScreen() throws -> NSScreen {
    try #require(NSScreen.screens.first)
}

func wallpaperWindowTestURL(_ name: String) -> URL {
    URL(fileURLWithPath: "/tmp/\(name)")
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
        case observeFailure(UUID)
        case cancel(UUID)
    }

    private final class ObservationToken: NSObject {
        let targetID: UUID

        init(targetID: UUID) {
            self.targetID = targetID
        }
    }

    private var handlers: [UUID: () -> Void] = [:]
    private var failureHandlers: [UUID: () -> Void] = [:]
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

    func observePlaybackFailure(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject {
        let targetID = targetID(for: target)
        failureHandlers[targetID] = { handler() }
        events.append(.observeFailure(targetID))
        return ObservationToken(targetID: targetID)
    }

    func cancelObservation(_ token: AnyObject) {
        guard let token = token as? ObservationToken else { return }
        events.append(.cancel(token.targetID))
        handlers[token.targetID] = nil
        failureHandlers[token.targetID] = nil
    }

    func emitPlaybackFinished(for target: FakePlaybackObservationTarget) {
        handlers[target.id]?()
    }

    func emitPlaybackFailed(for target: FakePlaybackObservationTarget) {
        failureHandlers[target.id]?()
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
