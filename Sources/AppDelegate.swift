import AVFoundation
import Cocoa
import IOKit.ps
import UniformTypeIdentifiers

@MainActor
protocol WallpaperWindowControlling: AnyObject {
    var onVideoDropped: ((URL, DisplayIdentifier) -> Void)? { get set }
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)? { get set }
    var onPlaybackFailed: ((DisplayIdentifier) -> Void)? { get set }

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
    private var displayErrors: [DisplayIdentifier: WallpaperError] = [:]

    init(
        screenProvider: @escaping () -> [NSScreen] = { NSScreen.screens },
        controllerFactory: @escaping (NSScreen) -> any WallpaperWindowControlling = { screen in
            WallpaperWindowController(screen: screen, videoURL: nil)
        },
        playlistStore: PlaylistStore = PlaylistPersistence().load(),
        isOnBatteryProvider: @escaping () -> Bool = defaultIsOnBattery
    ) {
        self.screenControllers = []
        self.playlistStore = playlistStore
        self.screenProvider = screenProvider
        self.controllerFactory = controllerFactory
        self.isOnBatteryProvider = isOnBatteryProvider
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
        menu.onVideoURLChanged = { [weak self] url, displayId in
            self?.handleVideoSelected(url, for: displayId)
        }
        menu.onVideoCleared = { [weak self] displayId in
            self?.handleVideoCleared(for: displayId)
        }
        menu.onDisplayToggled = { [weak self] displayId, enabled in
            self?.handleDisplayToggled(displayId, enabled: enabled)
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
        let targetScreens: [(id: CGDirectDisplayID, screen: NSScreen)] = screenProvider()
            .compactMap { screen in
                guard let id = displayID(for: screen),
                      let displayIdentifier = screen.displayIdentifier,
                      VideoFileValidator.isDisplayEnabled(displayIdentifier)
                else { return nil }
                return (id, screen)
            }

        let targetIDs = Set(targetScreens.map(\.0))
        var newScreenControllers: [ScreenController] = []

        for slot in screenControllers where !targetIDs.contains(slot.id) {
            slot.controller.invalidate()
        }
        screenControllers.removeAll { !targetIDs.contains($0.id) }

        let existingIDs = Set(screenControllers.map(\.id))
        for (id, screen) in targetScreens where !existingIDs.contains(id) {
            let controller = controllerFactory(screen)
            controller.onVideoDropped = { [weak self] url, displayID in
                let saved = VideoFileValidator.saveBookmark(for: url, display: displayID)
                if !saved {
                    self?.setError(.bookmarkSaveFailed(displayID), for: displayID)
                } else {
                    self?.clearError(for: displayID)
                }
                self?.reloadVideoForDisplay(displayID)
                self?.updateDisplayStates()
                self?.applyBatteryPolicy()
            }
            // Per-display mode has no playlist rotation; videos loop via AVPlayerLooper
            controller.onPlaybackFinished = { _ in }
            controller.onPlaybackFailed = { [weak self] displayID in
                self?.setError(.playbackFailed(displayID), for: displayID)
                self?.updateDisplayStates()
            }
            controller.applyDimLevel(DimLevel.saved.opacity)
            controller.applyVideoGravity(VideoGravity.saved)
            newScreenControllers.append(ScreenController(id: id, controller: controller))
        }
        screenControllers.append(contentsOf: newScreenControllers)

        let orderedIDs = targetScreens.map(\.0)
        screenControllers.sort { lhs, rhs in
            let lhsIndex = orderedIDs.firstIndex(of: lhs.id) ?? .max
            let rhsIndex = orderedIDs.firstIndex(of: rhs.id) ?? .max
            return lhsIndex < rhsIndex
        }
        for slot in newScreenControllers {
            let displayId = DisplayIdentifier(displayID: slot.id)
            loadVideoForDisplay(displayId, on: slot.controller)
        }
        applyBatteryPolicy(to: newScreenControllers.map(\.controller))
        updateDisplayStates()
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

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

@MainActor
private extension AppDelegate {
    func loadVideoForDisplay(
        _ displayId: DisplayIdentifier,
        on controller: any WallpaperWindowControlling
    ) {
        if let url = VideoFileValidator.resolveBookmarkedURL(display: displayId) {
            clearError(for: displayId)
            controller.load(videoURL: url, timeRange: nil, itemID: nil, token: nil)
        } else if VideoFileValidator.hasBookmark(display: displayId) {
            setError(.bookmarkResolveFailed(displayId), for: displayId)
            controller.clearVideo()
        } else {
            controller.clearVideo()
        }
    }

    func reloadVideoForDisplay(_ displayId: DisplayIdentifier) {
        guard let slot = screenControllers.first(where: {
            DisplayIdentifier(displayID: $0.id) == displayId
        }) else { return }
        loadVideoForDisplay(displayId, on: slot.controller)
    }

    func updateDisplayStates() {
        statusMenuController?.displayStates = buildDisplayStates()
    }

    func buildDisplayStates() -> [DisplayMenuState] {
        screenProvider().compactMap { screen -> DisplayMenuState? in
            guard let displayId = screen.displayIdentifier else { return nil }
            let isEnabled = VideoFileValidator.isDisplayEnabled(displayId)
            let url = VideoFileValidator.resolveBookmarkedURL(display: displayId)
            let errorMessage = displayErrors[displayId]?.localizedMessage
            return DisplayMenuState(
                displayIdentifier: displayId,
                screenName: screen.localizedName,
                isEnabled: isEnabled,
                currentVideoName: url?.lastPathComponent,
                errorMessage: errorMessage
            )
        }
    }

    func handleVideoSelected(_ url: URL, for displayId: DisplayIdentifier) {
        let saved = VideoFileValidator.saveBookmark(for: url, display: displayId)
        if saved {
            clearError(for: displayId)
        } else {
            setError(.bookmarkSaveFailed(displayId), for: displayId)
        }
        reloadVideoForDisplay(displayId)
        updateDisplayStates()
        applyBatteryPolicy()
    }

    func handleVideoCleared(for displayId: DisplayIdentifier) {
        VideoFileValidator.clearBookmark(display: displayId)
        clearError(for: displayId)
        reloadVideoForDisplay(displayId)
        updateDisplayStates()
    }

    func handleDisplayToggled(_ displayId: DisplayIdentifier, enabled: Bool) {
        VideoFileValidator.setDisplayEnabled(enabled, display: displayId)
        setupWallpaperWindows()
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
            self?.updatePlaylistItem(id: id, playbackSensitive: false) {
                $0.updateDisplayName(id: id, displayName: displayName)
            }
        }
        editor.onUseFullVideoChanged = { [weak self] id, useFullVideo in
            self?.updatePlaylistItem(id: id, playbackSensitive: true) {
                $0.updateUseFullVideo(id: id, useFullVideo: useFullVideo)
            }
        }
        editor.onTimeRangeChanged = { [weak self] id, startTime, endTime in
            self?.updatePlaylistItem(id: id, playbackSensitive: true) {
                let updatedStart = $0.updateStartTime(id: id, startTime: startTime)
                let updatedEnd = $0.updateEndTime(id: id, endTime: endTime)
                return updatedStart || updatedEnd
            }
        }
    }

    func presentVideoOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "m4v") ?? .movie
        ]
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls.filter { VideoFileValidator.isSupported(extension: $0.pathExtension) }
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
        guard playlistStore.delete(id: id) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func movePlaylistItem(id: PlaylistItem.ID, by offset: Int) {
        guard playlistStore.move(id: id, by: offset) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func setCurrentPlaylistItem(id: PlaylistItem.ID) {
        guard playlistStore.setCurrent(id: id) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func updatePlaylistItem(
        id: PlaylistItem.ID,
        playbackSensitive: Bool,
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

    func setError(_ error: WallpaperError, for displayId: DisplayIdentifier) {
        displayErrors[displayId] = error
    }

    func clearError(for displayId: DisplayIdentifier) {
        displayErrors[displayId] = nil
    }
}
