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
    private let player: AVPlayer
    private let playerLayer: AVPlayerLayer
    private let dimLayer: CALayer
    private var currentPlaybackContext: PlaybackContext?
    private var playbackCompletionObserver: NSObjectProtocol?
    private var currentVideoURL: URL?
    private var isScopedAccessActive = false
    private var occlusionObserver: NSObjectProtocol?

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?

    init(screen: NSScreen, videoURL url: URL?) {
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
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

        player = AVPlayer()
        player.isMuted = true

        let dropView = DropDestinationView(frame: window.frame)
        dropView.wantsLayer = true
        window.contentView = dropView

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = VideoGravity.saved.avGravity
        playerLayer.frame = dropView.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dropView.layer?.addSublayer(playerLayer)
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
                    if self.currentPlaybackContext != nil { self.player.play() }
                } else {
                    self.player.pause()
                }
            }
        }
    }

    func applyDimLevel(_ opacity: CGFloat) {
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    func applyVideoGravity(_ gravity: VideoGravity) {
        playerLayer.videoGravity = gravity.avGravity
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
            if window.occlusionState.contains(.visible) { player.play() }
            return
        }

        player.pause()
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        let playbackContext = PlaybackContext(
            itemID: itemID,
            url: url,
            timeRange: timeRange,
            token: token
        )
        currentPlaybackContext = playbackContext
        currentVideoURL = url
        isScopedAccessActive = url.startAccessingSecurityScopedResource()

        let item = AVPlayerItem(url: url)
        if let timeRange {
            item.forwardPlaybackEndTime = timeRange.end
        }
        player.replaceCurrentItem(with: item)
        observePlaybackCompletion(for: item, context: playbackContext)

        if let timeRange {
            player.seek(
                to: timeRange.start,
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { [weak self] finished in
                Task { @MainActor [weak self] in
                    guard finished, let self, self.isCurrentPlaybackContext(playbackContext) else {
                        return
                    }
                    self.player.play()
                }
            }
        } else {
            player.play()
        }
        // orderFront は AppDelegate の applyBatteryPolicy() が制御する
    }

    /// ビデオ再生を停止し、ウィンドウを非表示にする。
    /// セキュリティスコープアクセスを解放する。
    func clearVideo() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        currentVideoURL = nil
        currentPlaybackContext = nil
        window.orderOut(nil)
    }

    func resumePlayback() {
        guard currentPlaybackContext != nil else { return }
        window.orderFront(nil)
        if window.occlusionState.contains(.visible) { player.play() }
    }

    func pausePlayback() {
        player.pause()
        window.orderOut(nil)
    }

    /// Call from AppDelegate on the MainActor to release resources.
    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        stopObservingPlaybackCompletion()
        stopScopedAccessIfNeeded()
        currentVideoURL = nil
        currentPlaybackContext = nil
        window.close()
    }

    private func stopScopedAccessIfNeeded() {
        if isScopedAccessActive {
            currentVideoURL?.stopAccessingSecurityScopedResource()
            isScopedAccessActive = false
        }
    }

    private func stopObservingPlaybackCompletion() {
        if let playbackCompletionObserver {
            NotificationCenter.default.removeObserver(playbackCompletionObserver)
            self.playbackCompletionObserver = nil
        }
    }

    private func observePlaybackCompletion(for item: AVPlayerItem, context: PlaybackContext?) {
        guard let context else { return }

        playbackCompletionObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isCurrentPlaybackContext(context) else { return }
                guard let itemID = context.itemID, let token = context.token else { return }
                self.onPlaybackFinished?(PlaybackCompletion(itemID: itemID, token: token))
            }
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
