import Cocoa
import IOKit.ps

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
    private var isOnBattery: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
        return type == kIOPMBatteryPowerKey
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowControllers.forEach { $0.invalidate() }
        windowControllers.removeAll()
    }

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
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(powerSourceDidChange),
            name: NSNotification.Name(rawValue: kIOPSNotifyPowerSource),
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
        menu.onPowerSavingModeChanged = { [weak self] in
            self?.applyBatteryPolicy()
        }
        menu.onVideoGravityChanged = { [weak self] gravity in
            self?.windowControllers.forEach { $0.applyVideoGravity(gravity) }
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
            let controller = WallpaperWindowController(screen: screen, videoURL: savedURL)
            controller.onVideoDropped = { [weak self] url in
                // applyVideo() で全コントローラに新しい動画を適用する（マルチモニタ対応）。
                // ドロップされたコントローラ自身は DropDestinationView 内で load() 済みだが
                // 再度 load() しても問題ない（冪等）。
                // applyVideo() 内の applyBatteryPolicy() が省電力ポリシーも再適用する。
                self?.statusMenuController?.currentVideoName = url.lastPathComponent
                self?.applyVideo(url: url)
            }
            windowControllers.append(controller)
        }
    }

    private func applyVideo(url: URL) {
        windowControllers.forEach { $0.load(videoURL: url) }
        applyBatteryPolicy()  // 省電力一時停止中は orderFront しない
    }

    @objc private func screensDidChange() {
        setupWallpaperWindows()
    }

    @objc private func systemDidWake() {
        applyBatteryPolicy()
    }

    @objc private func powerSourceDidChange() {
        applyBatteryPolicy()
    }

    private func applyBatteryPolicy() {
        if PowerSavingMode.saved.shouldPause(isOnBattery: isOnBattery) {
            windowControllers.forEach { $0.pausePlayback() }
        } else {
            windowControllers.forEach { $0.resumePlayback() }
        }
    }
}
