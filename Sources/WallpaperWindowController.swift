import AVFoundation
import Cocoa

@MainActor
final class WallpaperWindowController {

    private struct PlaybackContext {
        let itemID: PlaylistItem.ID?
        let url: URL
        let timeRange: CMTimeRange?
        let token: RotationEngine<PlaylistItem>.PlaybackToken?
    }

    let displayIdentifier: DisplayIdentifier

    private let window: NSWindow
    private var isWindowOrderedFront = false
    private let driver: PlayerDriver
    private let dimLayer: CALayer
    private let playbackCompletionObserver: PlaybackCompletionObserver
    private let securityScopedAccessController: SecurityScopedAccessController
    private var currentPlaybackContext: PlaybackContext?
    private var currentObservationTarget: PlaybackObservationTarget?
    private var playbackCompletionObservationToken: AnyObject?
    private var playbackFailureObservationToken: AnyObject?
    private var securityScopedAccessHandle: SecurityScopedAccessHandle?
    private var isPlaybackStartPending = false
    private var isPlaybackPaused = true
    private var occlusionObserver: NSObjectProtocol?

    var onVideoDropped: ((URL, DisplayIdentifier) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?
    var onPlaybackFailed: ((DisplayIdentifier) -> Void)?

    convenience init(screen: NSScreen, videoURL url: URL?) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        let displayIdentifier = screen.displayIdentifier
            ?? DisplayIdentifier(vendor: 0, model: 0, serial: 0)
        self.init(
            window: window,
            displayIdentifier: displayIdentifier,
            videoURL: url,
            driverFactory: AVPlayerDriverFactory(),
            playbackCompletionObserver: NotificationPlaybackCompletionObserver(),
            securityScopedAccessController: URLSecurityScopedAccessController()
        )
    }

    init(
        window: NSWindow,
        displayIdentifier: DisplayIdentifier,
        videoURL url: URL?,
        driverFactory: PlayerDriverFactory,
        playbackCompletionObserver: PlaybackCompletionObserver,
        securityScopedAccessController: SecurityScopedAccessController
    ) {
        self.displayIdentifier = displayIdentifier
        self.window = window
        driver = driverFactory.makeDriver()
        self.playbackCompletionObserver = playbackCompletionObserver
        self.securityScopedAccessController = securityScopedAccessController

        // Sits just below the desktop icon layer
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        // Visible on all Spaces; excluded from Mission Control
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.ignoresMouseEvents = false  // required for drag-and-drop
        // Prevent AppKit from releasing the window on close (ARC manages lifetime)
        window.isReleasedWhenClosed = false

        let dropView = DropDestinationView(frame: window.frame)
        dropView.wantsLayer = true
        window.contentView = dropView

        driver.layer.videoGravity = VideoGravity.saved.avGravity
        driver.layer.frame = dropView.bounds
        driver.layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dropView.layer?.addSublayer(driver.layer)
        dimLayer = CALayer()
        dimLayer.frame = dropView.bounds
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        dropView.layer?.addSublayer(dimLayer)
        applyDimLevel(DimLevel.saved.opacity)
        dropView.onVideoDropped = { [weak self] url in
            guard let self else { return }
            self.onVideoDropped?(url, self.displayIdentifier)
        }

        if let url = url {
            load(videoURL: url)
            showWindowIfNeeded()
        }

        // Pause when covered by a fullscreen app; resume when visible again
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isWindowOrderedFront {
                    self.playIfNeeded()
                } else {
                    self.pausePlaybackIfNeeded()
                }
            }
        }
    }

    func applyDimLevel(_ opacity: CGFloat) {
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    func applyVideoGravity(_ gravity: VideoGravity) {
        driver.layer.videoGravity = gravity.avGravity
    }

    func load(videoURL url: URL) {
        load(videoURL: url, timeRange: nil, itemID: nil, token: nil)
    }

    func load(videoURL url: URL, timeRange: CMTimeRange?) {
        load(videoURL: url, timeRange: timeRange, itemID: nil, token: nil)
    }

    func load(
        videoURL url: URL,
        timeRange: CMTimeRange?,
        itemID: PlaylistItem.ID? = nil,
        token: RotationEngine<PlaylistItem>.PlaybackToken? = nil
    ) {
        let playbackContext = PlaybackContext(
            itemID: itemID,
            url: url,
            timeRange: timeRange,
            token: token
        )

        guard !isSamePlaybackTarget(url: url, timeRange: timeRange, itemID: itemID, token: token) else {
            if isWindowOrderedFront { playIfNeeded() }
            return
        }

        if isSameMediaTarget(url: url, timeRange: timeRange),
           let currentObservationTarget {
            isPlaybackStartPending = false
            pausePlaybackIfNeeded()
            stopObservingPlaybackCompletion()
            currentPlaybackContext = playbackContext
            observePlaybackCompletion(for: currentObservationTarget, context: playbackContext)
            startPlayback(for: playbackContext, reusingCurrentItem: true)
            return
        }

        isPlaybackStartPending = false
        pausePlaybackIfNeeded()
        stopObservingPlaybackCompletion()
        currentObservationTarget = nil
        stopScopedAccessIfNeeded()
        currentPlaybackContext = playbackContext
        securityScopedAccessHandle = securityScopedAccessController.startAccessing(url)

        let observationTarget = driver.replaceCurrentItem(
            with: url,
            forwardPlaybackEndTime: timeRange?.end
        )
        observePlaybackCompletion(for: observationTarget, context: playbackContext)
        startPlayback(for: playbackContext, reusingCurrentItem: false)
        // orderFront は AppDelegate の applyBatteryPolicy() が制御する
    }

    /// ビデオ再生を停止し、ウィンドウを非表示にする。
    /// セキュリティスコープアクセスを解放する。
    func clearVideo() {
        guard currentPlaybackContext != nil
            || currentObservationTarget != nil
            || isWindowOrderedFront
            || isPlaybackStartPending
            || !isPlaybackPaused
        else {
            return
        }
        currentPlaybackContext = nil
        currentObservationTarget = nil
        isPlaybackStartPending = false
        pausePlaybackIfNeeded()
        driver.clearCurrentItem()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        hideWindowIfNeeded()
    }

    func resumePlayback() {
        guard currentPlaybackContext != nil else { return }
        showWindowIfNeeded()
        playIfNeeded()
    }

    func pausePlayback() {
        pausePlaybackIfNeeded()
        hideWindowIfNeeded()
    }

    /// Call from AppDelegate on the MainActor to release resources.
    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        currentPlaybackContext = nil
        currentObservationTarget = nil
        isPlaybackStartPending = false
        pausePlaybackIfNeeded()
        driver.clearCurrentItem()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        hideWindowIfNeeded()
        window.close()
    }

    private func showWindowIfNeeded() {
        guard !isWindowOrderedFront else { return }
        window.orderFront(nil)
        isWindowOrderedFront = true
    }

    private func hideWindowIfNeeded() {
        guard isWindowOrderedFront else { return }
        window.orderOut(nil)
        isWindowOrderedFront = false
    }

    private func pausePlaybackIfNeeded() {
        guard !isPlaybackPaused else { return }
        driver.pause()
        isPlaybackPaused = true
    }

    private func playIfNeeded() {
        guard !isPlaybackStartPending else { return }
        guard isPlaybackPaused else { return }
        driver.play()
        isPlaybackPaused = false
    }

    private func stopScopedAccessIfNeeded() {
        securityScopedAccessHandle?.stop()
        securityScopedAccessHandle = nil
    }

    private func stopObservingPlaybackCompletion() {
        if let playbackCompletionObservationToken {
            playbackCompletionObserver.cancelObservation(playbackCompletionObservationToken)
            self.playbackCompletionObservationToken = nil
        }
        if let playbackFailureObservationToken {
            playbackCompletionObserver.cancelObservation(playbackFailureObservationToken)
            self.playbackFailureObservationToken = nil
        }
    }

    private func observePlaybackCompletion(
        for target: PlaybackObservationTarget,
        context: PlaybackContext?
    ) {
        guard let context else { return }
        currentObservationTarget = target

        playbackCompletionObservationToken = playbackCompletionObserver.observePlaybackCompletion(
            for: target
        ) { [weak self] in
            guard let self, self.isCurrentPlaybackContext(context) else { return }
            guard let itemID = context.itemID, let token = context.token else { return }
            self.onPlaybackFinished?(PlaybackCompletion(itemID: itemID, token: token))
        }

        playbackFailureObservationToken = playbackCompletionObserver.observePlaybackFailure(
            for: target
        ) { [weak self] in
            guard let self, self.isCurrentPlaybackContext(context) else { return }
            self.onPlaybackFailed?(self.displayIdentifier)
        }
    }

    private func isSameMediaTarget(url: URL, timeRange: CMTimeRange?) -> Bool {
        guard let currentPlaybackContext else { return false }
        guard currentPlaybackContext.url == url else { return false }
        return timeRangesEqual(currentPlaybackContext.timeRange, timeRange)
    }

    private func startPlayback(
        for context: PlaybackContext,
        reusingCurrentItem: Bool
    ) {
        if let timeRange = context.timeRange {
            seekAndPlay(to: timeRange.start, for: context)
        } else if reusingCurrentItem {
            seekAndPlay(to: .zero, for: context)
        } else {
            isPlaybackStartPending = false
            playIfNeeded()
        }
    }

    private func seekAndPlay(to time: CMTime, for context: PlaybackContext) {
        isPlaybackStartPending = true
        driver.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard finished, let self, self.isCurrentPlaybackContext(context) else {
                return
            }
            self.isPlaybackStartPending = false
            self.isPlaybackPaused = false
            self.driver.play()
        }
    }
}

private extension WallpaperWindowController {

    func isSamePlaybackTarget(
        url: URL,
        timeRange: CMTimeRange?,
        itemID: PlaylistItem.ID? = nil,
        token: RotationEngine<PlaylistItem>.PlaybackToken? = nil
    ) -> Bool {
        guard let currentPlaybackContext else { return false }
        guard currentPlaybackContext.url == url,
              currentPlaybackContext.itemID == itemID,
              currentPlaybackContext.token == token else { return false }
        return timeRangesEqual(currentPlaybackContext.timeRange, timeRange)
    }

    private func isCurrentPlaybackContext(_ context: PlaybackContext) -> Bool {
        guard let currentPlaybackContext else { return false }
        return currentPlaybackContext.url == context.url
            && currentPlaybackContext.itemID == context.itemID
            && currentPlaybackContext.token == context.token
            && timeRangesEqual(currentPlaybackContext.timeRange, context.timeRange)
    }

    func timeRangesEqual(_ lhs: CMTimeRange?, _ rhs: CMTimeRange?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (.some(lhs), .some(rhs)):
            return CMTimeRangeEqual(lhs, rhs)
        default:
            return false
        }
    }
}

extension WallpaperWindowController: WallpaperWindowControlling {}

@MainActor
private final class DropDestinationView: NSView {

    var onVideoDropped: ((URL) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard fileURL(from: sender) != nil else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender) else { return false }

        guard VideoFileValidator.isSupported(extension: url.pathExtension) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.unsupported_file.title")
            alert.informativeText = String(localized: "alert.unsupported_file.message")
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }

        onVideoDropped?(url)
        return true
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: nil)?
            .first as? URL
    }
}
