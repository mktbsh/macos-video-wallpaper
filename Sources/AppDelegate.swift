import AVFoundation
import Cocoa
import IOKit.ps

@MainActor
protocol WallpaperWindowControlling: AnyObject {
    var onVideoDropped: ((URL) -> Void)? { get set }
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)? { get set }
    var onPlaybackFailed: (() -> Void)? { get set }

    func load(
        videoURL url: URL,
        timeRange: CMTimeRange?,
        itemID: PlaylistItem.ID?,
        token: RotationEngine<PlaylistItem>.PlaybackToken?
    )
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
    private var playlistEditorWindowController: PlaylistEditorWindowController?
    private let playlistPersistence = PlaylistPersistence()
    private var playlistStore: PlaylistStore
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
        playlistStore: PlaylistStore = PlaylistPersistence().load(),
        isOnBatteryProvider: @escaping () -> Bool = defaultIsOnBattery,
        wallpaperVideoStore: any WallpaperVideoStoring = WallpaperVideoStore()
    ) {
        self.screenControllers = []
        self.playlistStore = playlistStore
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
            // Single global video loops via seek-to-start; no playlist rotation
            controller.onPlaybackFinished = { _ in }
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
            controllers.forEach { $0.load(videoURL: url, timeRange: nil, itemID: nil, token: nil) }
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

    func showPlaylistEditor() {
        let editor = playlistEditorWindowController ?? makePlaylistEditorWindowController()
        editor.reload(items: playlistStore.items, currentItemID: playlistStore.currentItem?.id)
        editor.showEditor()
    }

    func makePlaylistEditorWindowController() -> PlaylistEditorWindowController {
        let editor = PlaylistEditorWindowController()
        configure(editor: editor)
        editor.validateTimeRange = { _, start, end, useFullVideo in
            guard !useFullVideo else { return nil }
            guard let start, let end, end > start else {
                return String(localized: "playlist_editor.validation.invalid_range")
            }
            return nil
        }
        playlistEditorWindowController = editor
        return editor
    }

    func configure(editor: PlaylistEditorWindowController) {
        editor.onAddVideos = { [weak self] in
            self?.presentVideoOpenPanel()
        }
        editor.onDeleteItem = { [weak self] id in
            self?.deletePlaylistItem(id: id)
        }
        editor.onMoveItem = { [weak self] id, offset in
            self?.movePlaylistItem(id: id, by: offset)
        }
        editor.onSetCurrentItem = { [weak self] id in
            self?.setCurrentPlaylistItem(id: id)
        }
        editor.onDisplayNameChanged = { [weak self] id, displayName in
            self?.updatePlaylistItem {
                $0.updateDisplayName(id: id, displayName: displayName)
            }
        }
        editor.onUseFullVideoChanged = { [weak self] id, useFullVideo in
            self?.updatePlaylistItem {
                $0.updateUseFullVideo(id: id, useFullVideo: useFullVideo)
            }
        }
        editor.onTimeRangeChanged = { [weak self] id, startTime, endTime in
            self?.updatePlaylistItem {
                $0.updateTimeRange(id: id, startTime: startTime, endTime: endTime)
            }
        }
    }

    func presentVideoOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = VideoFileType.allowedUTTypes
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls.filter { VideoFileType.isSupported(extension: $0.pathExtension) }
        guard !urls.isEmpty else { return }

        playlistStore.add(urls: urls)
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func reloadPlaylistUI() {
        playlistEditorWindowController?.reload(
            items: playlistStore.items,
            currentItemID: playlistStore.currentItem?.id
        )
    }

    func deletePlaylistItem(id: PlaylistItem.ID) {
        updatePlaylistItem { $0.delete(id: id) }
    }

    func movePlaylistItem(id: PlaylistItem.ID, by offset: Int) {
        updatePlaylistItem { $0.move(id: id, by: offset) }
    }

    func setCurrentPlaylistItem(id: PlaylistItem.ID) {
        updatePlaylistItem { $0.setCurrent(id: id) }
    }

    func updatePlaylistItem(
        mutation: (inout PlaylistStore) -> Bool
    ) {
        guard mutation(&playlistStore) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func persistPlaylistState() {
        playlistPersistence.save(store: playlistStore)
    }

    // MARK: - Error management

    func setError(_ error: WallpaperError) {
        currentError = error
    }

    func clearError() {
        currentError = nil
    }
}
