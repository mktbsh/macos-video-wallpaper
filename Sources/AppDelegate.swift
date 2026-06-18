import AVFoundation
import Cocoa
import IOKit.ps

@MainActor
protocol WallpaperWindowControlling: AnyObject {
    var onVideoDropped: ((URL) -> Void)? { get set }
    var onPlaybackFailed: (() -> Void)? { get set }

    func load(videoURL url: URL)
    func clearVideo()
    func invalidate()
    func applyDimLevel(_ opacity: CGFloat)
    func applyVideoGravity(_ gravity: VideoGravity)
    func pausePlayback()
    func resumePlayback()
}

private func defaultIsOnBattery() -> Bool {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
    return type == kIOPMBatteryPowerKey
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private struct ScreenController {
        let id: CGDirectDisplayID
        let controller: any WallpaperWindowControlling
    }

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

    private var screenControllers: [ScreenController]
    private var statusMenuController: StatusMenuController?
    private let screenProvider: () -> [NSScreen]
    private let controllerFactory: (NSScreen) -> any WallpaperWindowControlling
    private let isOnBatteryProvider: () -> Bool
    private let wallpaperVideoStore: any WallpaperVideoStoring
    private var currentError: WallpaperError?

    init(
        screenProvider: @escaping () -> [NSScreen] = { NSScreen.screens },
        controllerFactory: @escaping (NSScreen) -> any WallpaperWindowControlling = { screen in
            WallpaperWindowController(screen: screen, videoURL: nil)
        },
        isOnBatteryProvider: @escaping () -> Bool = defaultIsOnBattery,
        wallpaperVideoStore: any WallpaperVideoStoring = WallpaperVideoStore()
    ) {
        self.screenControllers = []
        self.screenProvider = screenProvider
        self.controllerFactory = controllerFactory
        self.isOnBatteryProvider = isOnBatteryProvider
        self.wallpaperVideoStore = wallpaperVideoStore
    }

    private var isOnBattery: Bool {
        isOnBatteryProvider()
    }

    func applicationWillTerminate(_ notification: Notification) {
        screenControllers.forEach { $0.controller.invalidate() }
        screenControllers.removeAll()
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
            self?.handleVideoSelected(url)
        }
        menu.onVideoCleared = { [weak self] in
            self?.handleVideoCleared()
        }
        menu.onDimLevelChanged = { [weak self] opacity in
            self?.screenControllers.forEach { $0.controller.applyDimLevel(opacity) }
        }
        menu.onPowerSavingModeChanged = { [weak self] in
            self?.applyBatteryPolicy()
        }
        menu.onVideoGravityChanged = { [weak self] gravity in
            self?.screenControllers.forEach { $0.controller.applyVideoGravity(gravity) }
        }
        statusMenuController = menu

        setupWallpaperWindows()
    }

    // MARK: - Private

    private func setupWallpaperWindows() {
        // 全ディスプレイに壁紙を表示する（per-display の有効/無効はない）。
        let targetScreens: [(id: CGDirectDisplayID, screen: NSScreen)] = screenProvider()
            .compactMap { screen in
                guard let id = screen.displayID else { return nil }
                return (id, screen)
            }

        let targetIDs = Set(targetScreens.map(\.id))
        var newScreenControllers: [ScreenController] = []

        screenControllers.removeAll { slot in
            guard !targetIDs.contains(slot.id) else { return false }
            slot.controller.invalidate()
            return true
        }

        let existingIDs = Set(screenControllers.map(\.id))
        for (id, screen) in targetScreens where !existingIDs.contains(id) {
            let controller = controllerFactory(screen)
            controller.onVideoDropped = { [weak self] url in
                self?.handleVideoSelected(url)
            }
            controller.onPlaybackFailed = { [weak self] in
                self?.setError(.playbackFailed)
                self?.updateMenuState()
            }
            controller.applyDimLevel(DimLevel.saved.opacity)
            controller.applyVideoGravity(VideoGravity.saved)
            newScreenControllers.append(ScreenController(id: id, controller: controller))
        }
        screenControllers.append(contentsOf: newScreenControllers)

        // CGDirectDisplayID is unique among active displays; keep the first
        // occurrence to stay defensive against any duplicate input.
        let orderByID = Dictionary(
            targetScreens.enumerated().map { ($1.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        screenControllers.sort { lhs, rhs in
            (orderByID[lhs.id] ?? .max) < (orderByID[rhs.id] ?? .max)
        }
        // 画面再構成では新規 controller のみ load（生存 controller は同一動画を保持済み）。
        applyGlobalVideo(to: newScreenControllers.map(\.controller))
        applyBatteryPolicy(to: newScreenControllers.map(\.controller))
        updateMenuState()
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
        applyBatteryPolicy(to: screenControllers.map(\.controller))
    }

    private func applyBatteryPolicy(to controllers: [any WallpaperWindowControlling]) {
        if PowerSavingMode.saved.shouldPause(isOnBattery: isOnBattery) {
            controllers.forEach { $0.pausePlayback() }
        } else {
            controllers.forEach { $0.resumePlayback() }
        }
    }

}

// 壁紙のオーケストレーション。グローバル動画ストア seam を経由し、
// テストから @testable で直接検証できるよう internal に置く。
@MainActor
extension AppDelegate {
    /// グローバル動画の解決結果を対象 controller 群に適用する。
    /// `setupWallpaperWindows` は新規 controller のみ、動画変更時は全 controller を渡す。
    func applyGlobalVideo(to controllers: [any WallpaperWindowControlling]) {
        switch wallpaperVideoStore.resolveVideo() {
        case .resolved(let url):
            clearError()
            controllers.forEach { $0.load(videoURL: url) }
        case .resolveFailed:
            Log.persistence.warning("Wallpaper bookmark resolve failed")
            setError(.bookmarkResolveFailed)
            controllers.forEach { $0.clearVideo() }
        case .noVideo:
            controllers.forEach { $0.clearVideo() }
        }
    }

    func buildWallpaperMenuState() -> WallpaperMenuState {
        var currentVideoName: String?
        if case .resolved(let url) = wallpaperVideoStore.resolveVideo() {
            currentVideoName = url.lastPathComponent
        }
        return WallpaperMenuState(
            currentVideoName: currentVideoName,
            errorMessage: currentError?.localizedMessage
        )
    }

    func handleVideoSelected(_ url: URL) {
        if wallpaperVideoStore.saveVideo(url) {
            clearError()
        } else {
            Log.persistence.error("Wallpaper bookmark save failed for \(url.lastPathComponent, privacy: .public)")
            setError(.bookmarkSaveFailed)
        }
        applyGlobalVideo(to: allControllers)
        updateMenuState()
        applyBatteryPolicy()
    }

    func handleVideoCleared() {
        wallpaperVideoStore.clearVideo()
        clearError()
        applyGlobalVideo(to: allControllers)
        updateMenuState()
    }
}

@MainActor
private extension AppDelegate {
    var allControllers: [any WallpaperWindowControlling] {
        screenControllers.map(\.controller)
    }

    func updateMenuState() {
        statusMenuController?.wallpaperState = buildWallpaperMenuState()
    }

    // MARK: - Error management

    func setError(_ error: WallpaperError) {
        currentError = error
    }

    func clearError() {
        currentError = nil
    }
}
