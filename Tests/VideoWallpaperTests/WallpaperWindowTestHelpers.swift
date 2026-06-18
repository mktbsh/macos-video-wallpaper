import AppKit
import AVFoundation
import Foundation
import QuartzCore
import Testing
@testable import VideoWallpaper

@MainActor
struct WallpaperWindowControllerTestContext {
    let window: FakeWindow
    let driver: FakePlayerDriver
    let factory: FakePlayerDriverFactory
    let accessController: FakeSecurityScopedAccessController
    let controller: WallpaperWindowController

    init() throws {
        let window = FakeWindow(contentRect: try makeScreen().frame)
        let driver = FakePlayerDriver()
        let factory = FakePlayerDriverFactory(driver: driver)
        let accessController = FakeSecurityScopedAccessController()

        self.window = window
        self.driver = driver
        self.factory = factory
        self.accessController = accessController
        controller = WallpaperWindowController(
            window: window,
            videoURL: nil,
            driverFactory: factory,
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
    private(set) var requestedURLs: [URL] = []

    init(driver: FakePlayerDriver) {
        self.driver = driver
    }

    func makeDriver(for url: URL) -> PlayerDriver {
        requestedURLs.append(url)
        return driver
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
    let layer = CALayer()
    var onPlaybackFailed: (() -> Void)?

    private(set) var loadedURLs: [URL] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearCallCount = 0
    private(set) var appliedGravities: [VideoGravity] = []

    func load(url: URL) { loadedURLs.append(url) }
    func play() { playCallCount += 1 }
    func pause() { pauseCallCount += 1 }
    func clear() { clearCallCount += 1 }
    func applyGravity(_ gravity: VideoGravity) { appliedGravities.append(gravity) }

    func emitPlaybackFailed() { onPlaybackFailed?() }
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
