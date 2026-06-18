import AVFoundation
import Cocoa

@MainActor
final class WallpaperWindowController {

    private let window: NSWindow
    private var isWindowOrderedFront = false
    private let driverFactory: PlayerDriverFactory
    private let dimLayer: CALayer
    private let securityScopedAccessController: SecurityScopedAccessController
    private var driver: PlayerDriver?
    private var currentURL: URL?
    private var securityScopedAccessHandle: SecurityScopedAccessHandle?
    private var isPlaybackPaused = true
    private var occlusionObserver: NSObjectProtocol?

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFailed: (() -> Void)?

    convenience init(screen: NSScreen, videoURL url: URL?) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        self.init(
            window: window,
            videoURL: url,
            driverFactory: MediaPlayerDriverFactory(),
            securityScopedAccessController: URLSecurityScopedAccessController()
        )
    }

    init(
        window: NSWindow,
        videoURL url: URL?,
        driverFactory: PlayerDriverFactory,
        securityScopedAccessController: SecurityScopedAccessController
    ) {
        self.window = window
        self.driverFactory = driverFactory
        self.securityScopedAccessController = securityScopedAccessController

        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false

        let dropView = DropDestinationView(frame: window.frame)
        dropView.wantsLayer = true
        window.contentView = dropView

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
            showWindowIfNeeded()
        }

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
        driver?.applyGravity(gravity)
    }

    func load(videoURL url: URL) {
        guard currentURL != url else {
            if isWindowOrderedFront { playIfNeeded() }
            return
        }
        teardownDriver()
        currentURL = url
        securityScopedAccessHandle = securityScopedAccessController.startAccessing(url)

        let driver = driverFactory.makeDriver(for: url)
        driver.onPlaybackFailed = { [weak self] in
            self?.onPlaybackFailed?()
        }
        driver.applyGravity(VideoGravity.saved)
        if let hostLayer = window.contentView?.layer {
            driver.layer.frame = hostLayer.bounds
            driver.layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            hostLayer.insertSublayer(driver.layer, below: dimLayer)
        }
        self.driver = driver
        driver.load(url: url)
        isPlaybackPaused = true
        // orderFront / play は AppDelegate の applyBatteryPolicy() が制御する
    }

    func clearVideo() {
        guard isActive else { return }
        performClearVideo()
    }

    func resumePlayback() {
        guard currentURL != nil else { return }
        showWindowIfNeeded()
        playIfNeeded()
    }

    func pausePlayback() {
        pausePlaybackIfNeeded()
        hideWindowIfNeeded()
    }

    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        performClearVideo()
        window.close()
    }

    private var isActive: Bool {
        currentURL != nil || isWindowOrderedFront || !isPlaybackPaused
    }

    private func performClearVideo() {
        currentURL = nil
        teardownDriver()
        hideWindowIfNeeded()
    }

    private func teardownDriver() {
        driver?.pause()
        driver?.clear()
        driver?.layer.removeFromSuperlayer()
        driver = nil
        isPlaybackPaused = true
        stopScopedAccessIfNeeded()
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
        driver?.pause()
        isPlaybackPaused = true
    }

    private func playIfNeeded() {
        guard isPlaybackPaused else { return }
        guard driver != nil else { return }
        driver?.play()
        isPlaybackPaused = false
    }

    private func stopScopedAccessIfNeeded() {
        securityScopedAccessHandle?.stop()
        securityScopedAccessHandle = nil
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
        guard let url = fileURL(from: sender),
              VideoFileType.isSupported(extension: url.pathExtension) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender) else { return false }

        guard VideoFileType.isSupported(extension: url.pathExtension) else {
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
