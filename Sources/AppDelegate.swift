import Cocoa
import IOKit.ps
import UniformTypeIdentifiers

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private struct ScreenController {
        let id: CGDirectDisplayID
        let controller: WallpaperWindowController
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

    private var screenControllers: [ScreenController] = []
    private var statusMenuController: StatusMenuController?
    private var playlistEditorWindowController: PlaylistEditorWindowController?
    private let playlistPersistence = PlaylistPersistence()
    private var playlistStore = PlaylistStore()
    private var playbackSession = PlaybackSession()
    private var isOnBattery: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
        return type == kIOPMBatteryPowerKey
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
        playlistStore = playlistPersistence.load()

        let menu = StatusMenuController()
        menu.onAddVideos = { [weak self] in
            self?.presentVideoOpenPanel()
        }
        menu.onEditPlaylist = { [weak self] in
            self?.showPlaylistEditor()
        }
        menu.onNext = { [weak self] in
            self?.advanceToNextItem()
        }
        menu.onPrevious = { [weak self] in
            self?.moveToPreviousItem()
        }
        menu.onClear = { [weak self] in
            self?.clearPlaylist()
        }
        menu.onScreenTargetChanged = { [weak self] in self?.setupWallpaperWindows() }
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
        reloadPlaylistUI()
    }

    // MARK: - Private

    private func setupWallpaperWindows() {
        let targetScreens: [(id: CGDirectDisplayID, screen: NSScreen)] = ScreenTarget.saved
            .filter(NSScreen.screens)
            .compactMap { screen in
                guard let id = displayID(for: screen) else { return nil }
                return (id, screen)
            }

        let targetIDs = Set(targetScreens.map(\.0))

        for slot in screenControllers where !targetIDs.contains(slot.id) {
            slot.controller.invalidate()
        }
        screenControllers.removeAll { !targetIDs.contains($0.id) }

        let existingIDs = Set(screenControllers.map(\.id))
        for (id, screen) in targetScreens where !existingIDs.contains(id) {
            let controller = WallpaperWindowController(screen: screen, videoURL: nil)
            controller.onVideoDropped = { [weak self] url in
                self?.replacePlaylist(with: [url], setAsCurrent: true)
            }
            controller.onPlaybackFinished = { [weak self] completion in
                self?.handlePlaybackFinished(completion)
            }
            controller.applyDimLevel(DimLevel.saved.opacity)
            controller.applyVideoGravity(VideoGravity.saved)
            screenControllers.append(ScreenController(id: id, controller: controller))
        }

        let orderedIDs = targetScreens.map(\.0)
        screenControllers.sort { lhs, rhs in
            let lhsIndex = orderedIDs.firstIndex(of: lhs.id) ?? .max
            let rhsIndex = orderedIDs.firstIndex(of: rhs.id) ?? .max
            return lhsIndex < rhsIndex
        }
        applyCurrentPlaylistItem()
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
            screenControllers.forEach { $0.controller.pausePlayback() }
        } else {
            screenControllers.forEach { $0.controller.resumePlayback() }
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    private func presentVideoOpenPanel() {
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

        let shouldReplace = playlistStore.items.isEmpty
        if shouldReplace {
            replacePlaylist(with: urls, setAsCurrent: true)
        } else {
            playlistStore.add(urls: urls)
            persistPlaylistState()
            reloadPlaylistUI()
        }
    }

    private func replacePlaylist(with urls: [URL], setAsCurrent: Bool) {
        guard !urls.isEmpty else { return }
        playlistStore.replace(urls: urls)
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func advanceToNextItem() {
        guard playlistStore.next() else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func moveToPreviousItem() {
        guard playlistStore.previous() else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func clearPlaylist() {
        playlistStore.clear()
        playlistPersistence.clear()
        applyCurrentPlaylistItem()
    }

    private func applyCurrentPlaylistItem() {
        if let playback = playbackSession.beginPlayback(using: &playlistStore) {
            screenControllers.forEach {
                $0.controller.load(
                    videoURL: playback.item.url,
                    timeRange: playback.item.playbackTimeRange,
                    itemID: playback.item.id,
                    token: playback.token
                )
            }
        } else {
            screenControllers.forEach { $0.controller.clearVideo() }
        }
        reloadPlaylistUI()
        applyBatteryPolicy()  // 省電力一時停止中は orderFront しない
    }

    private func handlePlaybackFinished(_ completion: PlaybackCompletion) {
        guard playbackSession.consume(completion, using: &playlistStore) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func reloadPlaylistUI() {
        statusMenuController?.playlistSummary = playlistStore.summary
        playlistEditorWindowController?.reload(
            items: playlistStore.items,
            currentItemID: playlistStore.currentItem?.id
        )
    }

    private func showPlaylistEditor() {
        let editor = playlistEditorWindowController ?? makePlaylistEditorWindowController()
        editor.reload(items: playlistStore.items, currentItemID: playlistStore.currentItem?.id)
        editor.showEditor()
    }

    private func makePlaylistEditorWindowController() -> PlaylistEditorWindowController {
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

    private func configure(editor: PlaylistEditorWindowController) {
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
        editor.onStartTimeChanged = { [weak self] id, startTime in
            self?.updatePlaylistItem(id: id, playbackSensitive: true) {
                $0.updateStartTime(id: id, startTime: startTime)
            }
        }
        editor.onEndTimeChanged = { [weak self] id, endTime in
            self?.updatePlaylistItem(id: id, playbackSensitive: true) {
                $0.updateEndTime(id: id, endTime: endTime)
            }
        }
    }

    private func deletePlaylistItem(id: PlaylistItem.ID) {
        guard playlistStore.delete(id: id) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func movePlaylistItem(id: PlaylistItem.ID, by offset: Int) {
        guard playlistStore.move(id: id, by: offset) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    private func setCurrentPlaylistItem(id: PlaylistItem.ID) {
        guard playlistStore.setCurrent(id: id) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    private func updatePlaylistItem(
        id: PlaylistItem.ID,
        playbackSensitive: Bool,
        mutation: (inout PlaylistStore) -> Bool
    ) {
        guard mutation(&playlistStore) else { return }
        persistPlaylistState()

        if playbackSensitive, playlistStore.currentItem?.id == id {
            applyCurrentPlaylistItem()
        } else {
            reloadPlaylistUI()
        }
    }

    private func persistPlaylistState() {
        playlistPersistence.save(store: playlistStore)
    }
}
