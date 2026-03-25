import Cocoa
import AVFoundation

@MainActor
final class WallpaperWindowController {

    private let window: NSWindow
    private let player: AVQueuePlayer
    private let playerLayer: AVPlayerLayer
    private var playerLooper: AVPlayerLooper?

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
        dropView.onVideoDropped = { [weak self] url in
            UserDefaults.standard.set(url.path, forKey: "videoFilePath")
            self?.load(videoURL: url)
        }

        if let url = url {
            load(videoURL: url)
        }

        window.orderFront(nil)
    }

    func load(videoURL url: URL) {
        playerLooper = nil  // releases previous looper
        playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func resumePlayback() {
        if playerLooper != nil {
            player.play()
        }
    }

    /// Call from AppDelegate on the MainActor to release resources.
    func invalidate() {
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
