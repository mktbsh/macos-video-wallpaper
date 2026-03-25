import Cocoa

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // NSApplicationMain relies on a NIB to wire the delegate; since NSMainNibFile is empty,
    // manually set the delegate and call finishLaunching() before starting the run loop.
    nonisolated static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.finishLaunching()
            app.run()
        }
    }

    private var windowControllers: [WallpaperWindowController] = []
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        let menu = StatusMenuController()
        menu.onVideoURLChanged = { [weak self] url in
            self?.applyVideo(url: url)
        }
        menu.currentVideoName = VideoFileValidator
            .resolveBookmarkedURL()
            .map { $0.lastPathComponent }
        menu.onScreenTargetChanged = { [weak self] in self?.setupWallpaperWindows() }
        menu.onDimLevelChanged = { [weak self] opacity in
            self?.windowControllers.forEach { $0.applyDimLevel(opacity) }
        }
        statusMenuController = menu

        setupWallpaperWindows()
    }

    // MARK: - Private

    private func setupWallpaperWindows() {
        windowControllers.forEach { $0.invalidate() }
        windowControllers.removeAll()

        let savedURL = VideoFileValidator.resolveBookmarkedURL()
        for screen in ScreenTarget.saved.filter(NSScreen.screens) {
            windowControllers.append(WallpaperWindowController(screen: screen, videoURL: savedURL))
        }
    }

    private func applyVideo(url: URL) {
        windowControllers.forEach { $0.load(videoURL: url) }
    }

    @objc private func screensDidChange() {
        setupWallpaperWindows()
    }

    @objc private func systemDidWake() {
        windowControllers.forEach { $0.resumePlayback() }
    }
}
