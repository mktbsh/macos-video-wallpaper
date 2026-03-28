import AVFoundation
import Cocoa
import IOKit.ps
import UniformTypeIdentifiers

@MainActor
protocol WallpaperWindowControlling: AnyObject {
    var onVideoDropped: ((URL) -> Void)? { get set }
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)? { get set }

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
    private var playbackSession: PlaybackSession
    private let screenProvider: () -> [NSScreen]
    private let controllerFactory: (NSScreen) -> any WallpaperWindowControlling
    private let isOnBatteryProvider: () -> Bool

    init(
        screenProvider: @escaping () -> [NSScreen] = { NSScreen.screens },
        controllerFactory: @escaping (NSScreen) -> any WallpaperWindowControlling = { screen in
            WallpaperWindowController(screen: screen, videoURL: nil)
        },
        playlistStore: PlaylistStore = PlaylistPersistence().load(),
        playbackSession: PlaybackSession = PlaybackSession(),
        isOnBatteryProvider: @escaping () -> Bool = defaultIsOnBattery
    ) {
        self.screenControllers = []
        self.playlistStore = playlistStore
        self.playbackSession = playbackSession
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
            .filter(screenProvider())
            .compactMap { screen in
                guard let id = displayID(for: screen) else { return nil }
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
            controller.onVideoDropped = { [weak self] url in
                self?.replacePlaylist(with: [url], setAsCurrent: true)
            }
            controller.onPlaybackFinished = { [weak self] completion in
                self?.handlePlaybackFinished(completion)
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
        applyCurrentPlayback(
            to: newScreenControllers.map(\.controller),
            reuseExistingToken: true
        )
        applyBatteryPolicy(to: newScreenControllers.map(\.controller))
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
}

@MainActor
private extension AppDelegate {
    func applyCurrentPlaylistItem() {
        applyCurrentPlayback(
            to: screenControllers.map(\.controller),
            reuseExistingToken: false
        )
        reloadPlaylistUI()
        applyBatteryPolicy()  // 省電力一時停止中は orderFront しない
    }

    func applyCurrentPlayback(
        to controllers: [any WallpaperWindowControlling],
        reuseExistingToken: Bool
    ) {
        guard !controllers.isEmpty else { return }

        if let playback = playbackRequest(reusingExistingToken: reuseExistingToken) {
            controllers.forEach {
                $0.load(
                    videoURL: playback.item.url,
                    timeRange: playback.item.playbackTimeRange,
                    itemID: playback.item.id,
                    token: playback.token
                )
            }
        } else {
            controllers.forEach { $0.clearVideo() }
        }
    }

    func playbackRequest(reusingExistingToken: Bool) -> PlaybackSession.PlaybackRequest? {
        guard let currentItem = playlistStore.currentItem else { return nil }

        if reusingExistingToken, let currentToken = playbackSession.currentToken {
            return PlaybackSession.PlaybackRequest(item: currentItem, token: currentToken)
        }

        return playbackSession.beginPlayback(using: &playlistStore)
    }

    func handlePlaybackFinished(_ completion: PlaybackCompletion) {
        guard playbackSession.consume(completion, using: &playlistStore) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    func reloadPlaylistUI() {
        statusMenuController?.playlistSummary = playlistStore.summary
        playlistEditorWindowController?.reload(
            items: playlistStore.items,
            currentItemID: playlistStore.currentItem?.id
        )
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

    func deletePlaylistItem(id: PlaylistItem.ID) {
        guard playlistStore.delete(id: id) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    func movePlaylistItem(id: PlaylistItem.ID, by offset: Int) {
        guard playlistStore.move(id: id, by: offset) else { return }
        persistPlaylistState()
        reloadPlaylistUI()
    }

    func setCurrentPlaylistItem(id: PlaylistItem.ID) {
        guard playlistStore.setCurrent(id: id) else { return }
        persistPlaylistState()
        applyCurrentPlaylistItem()
    }

    func updatePlaylistItem(
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

    func persistPlaylistState() {
        playlistPersistence.save(store: playlistStore)
    }
}
