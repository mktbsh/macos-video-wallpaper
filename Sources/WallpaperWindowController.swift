import Cocoa
import AVFoundation

@MainActor
final class WallpaperWindowController {

    private let window: NSWindow
    private let player: AVQueuePlayer
    private let playerLayer: AVPlayerLayer
    private let dimLayer: CALayer
    private var playerLooper: AVPlayerLooper?
    private var occlusionObserver: NSObjectProtocol?

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

        player = AVQueuePlayer()
        player.isMuted = true

        let dropView = DropDestinationView(frame: window.frame)
        dropView.wantsLayer = true
        window.contentView = dropView

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
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
            VideoFileValidator.saveBookmark(for: url)
            self?.load(videoURL: url)
        }

        if let url = url {
            load(videoURL: url)
        }

        window.orderFront(nil)

        // Pause when covered by a fullscreen app; resume when visible again
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.window.occlusionState.contains(.visible) {
                    if self.playerLooper != nil { self.player.play() }
                } else {
                    self.player.pause()
                }
            }
        }
    }

    func applyDimLevel(_ opacity: CGFloat) {
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    func load(videoURL url: URL) {
        playerLooper = nil  // releases previous looper
        playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func resumePlayback() {
        guard playerLooper != nil, window.occlusionState.contains(.visible) else { return }
        player.play()
    }

    /// Call from AppDelegate on the MainActor to release resources.
    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        playerLooper = nil
        player.pause()
        window.close()
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
            alert.messageText = "サポートされていないファイル形式です"
            alert.informativeText = "MP4、MOV、M4V 形式の動画ファイルを選択してください。"
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
