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

    private let window: NSWindow
    private let driver: PlayerDriver
    private let dimLayer: CALayer
    private let playbackCompletionObserver: PlaybackCompletionObserver
    private let securityScopedAccessController: SecurityScopedAccessController
    private var currentPlaybackContext: PlaybackContext?
    private var playbackCompletionObservationToken: AnyObject?
    private var securityScopedAccessHandle: SecurityScopedAccessHandle?
    private var occlusionObserver: NSObjectProtocol?

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?

    convenience init(screen: NSScreen, videoURL url: URL?) {
        self.init(
            screen: screen,
            videoURL: url,
            driverFactory: AVPlayerDriverFactory(),
            playbackCompletionObserver: NotificationPlaybackCompletionObserver(),
            securityScopedAccessController: URLSecurityScopedAccessController()
        )
    }

    init(
        screen: NSScreen,
        videoURL url: URL?,
        driverFactory: PlayerDriverFactory,
        playbackCompletionObserver: PlaybackCompletionObserver,
        securityScopedAccessController: SecurityScopedAccessController
    ) {
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        driver = driverFactory.makeDriver()
        self.playbackCompletionObserver = playbackCompletionObserver
        self.securityScopedAccessController = securityScopedAccessController
        window.setFrameOrigin(screen.frame.origin)
        window.setContentSize(screen.frame.size)

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
            self?.onVideoDropped?(url)
        }

        if let url = url {
            load(videoURL: url)
            window.orderFront(nil)
        }

        // Pause when covered by a fullscreen app; resume when visible again
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.window.occlusionState.contains(.visible) {
                    if self.currentPlaybackContext != nil { self.driver.play() }
                } else {
                    self.driver.pause()
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
        guard !isSamePlaybackTarget(url: url, timeRange: timeRange, itemID: itemID, token: token) else {
            if window.occlusionState.contains(.visible) { driver.play() }
            return
        }

        driver.pause()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        let playbackContext = PlaybackContext(
            itemID: itemID,
            url: url,
            timeRange: timeRange,
            token: token
        )
        currentPlaybackContext = playbackContext
        securityScopedAccessHandle = securityScopedAccessController.startAccessing(url)

        let observationTarget = driver.replaceCurrentItem(
            with: url,
            forwardPlaybackEndTime: timeRange?.end
        )
        observePlaybackCompletion(for: observationTarget, context: playbackContext)

        if let timeRange {
            driver.seek(
                to: timeRange.start,
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { [weak self] finished in
                guard finished, let self, self.isCurrentPlaybackContext(playbackContext) else {
                    return
                }
                self.driver.play()
            }
        } else {
            driver.play()
        }
        // orderFront は AppDelegate の applyBatteryPolicy() が制御する
    }

    /// ビデオ再生を停止し、ウィンドウを非表示にする。
    /// セキュリティスコープアクセスを解放する。
    func clearVideo() {
        currentPlaybackContext = nil
        driver.pause()
        driver.clearCurrentItem()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        window.orderOut(nil)
    }

    func resumePlayback() {
        guard currentPlaybackContext != nil else { return }
        window.orderFront(nil)
        if window.occlusionState.contains(.visible) { driver.play() }
    }

    func pausePlayback() {
        driver.pause()
        window.orderOut(nil)
    }

    /// Call from AppDelegate on the MainActor to release resources.
    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        currentPlaybackContext = nil
        driver.pause()
        driver.clearCurrentItem()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        window.close()
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
    }

    private func observePlaybackCompletion(
        for target: PlaybackObservationTarget,
        context: PlaybackContext?
    ) {
        guard let context else { return }

        playbackCompletionObservationToken = playbackCompletionObserver.observePlaybackCompletion(
            for: target
        ) { [weak self] in
            guard let self, self.isCurrentPlaybackContext(context) else { return }
            guard let itemID = context.itemID, let token = context.token else { return }
            self.onPlaybackFinished?(PlaybackCompletion(itemID: itemID, token: token))
        }
    }

    private func isSamePlaybackTarget(
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

    private func timeRangesEqual(_ lhs: CMTimeRange?, _ rhs: CMTimeRange?) -> Bool {
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
