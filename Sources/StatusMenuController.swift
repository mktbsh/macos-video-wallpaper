import Cocoa
import ServiceManagement

private struct SelectionMenuEntry {
    let title: String
    let rawValue: String
    let action: Selector
}

@MainActor
final class StatusMenuController {

    var onAddVideos: (() -> Void)?
    var onEditPlaylist: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onClear: (() -> Void)?
    var onDimLevelChanged: ((CGFloat) -> Void)?
    var onPowerSavingModeChanged: (() -> Void)?
    var onVideoGravityChanged: ((VideoGravity) -> Void)?

    var playlistSummary: PlaylistSummary? {
        didSet { refreshPlaylistSection() }
    }

    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let summaryItem: NSMenuItem
    private let currentItem: NSMenuItem
    private let playlistSeparator: NSMenuItem
    private let addItem: NSMenuItem
    private let editItem: NSMenuItem
    private let previousItem: NSMenuItem
    private let nextItem: NSMenuItem
    private let clearItem: NSMenuItem
    private let dimMenu: NSMenu
    private let dimItem: NSMenuItem
    private let powerMenu: NSMenu
    private let powerItem: NSMenuItem
    private let gravityMenu: NSMenu
    private let gravityItem: NSMenuItem
    private let loginItem: NSMenuItem
    private let versionItem: NSMenuItem
    private let quitItem: NSMenuItem
    private var loginItemEnabled: Bool = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        summaryItem = NSMenuItem()
        currentItem = NSMenuItem()
        playlistSeparator = .separator()
        addItem = NSMenuItem(
            title: String(localized: "menu.playlist.add_videos"),
            action: #selector(addVideosAction),
            keyEquivalent: ""
        )
        editItem = NSMenuItem(
            title: String(localized: "menu.playlist.edit"),
            action: #selector(editPlaylistAction),
            keyEquivalent: ""
        )
        previousItem = NSMenuItem(
            title: String(localized: "menu.playlist.previous"),
            action: #selector(previousPlaylistAction),
            keyEquivalent: ""
        )
        nextItem = NSMenuItem(
            title: String(localized: "menu.playlist.next"),
            action: #selector(nextPlaylistAction),
            keyEquivalent: ""
        )
        clearItem = NSMenuItem(
            title: String(localized: "menu.playlist.clear"),
            action: #selector(clearPlaylistAction),
            keyEquivalent: ""
        )
        dimMenu = NSMenu()
        dimItem = NSMenuItem(
            title: String(localized: "menu.dim_level"),
            action: nil,
            keyEquivalent: ""
        )
        powerMenu = NSMenu()
        powerItem = NSMenuItem(
            title: String(localized: "menu.power_saving"),
            action: nil,
            keyEquivalent: ""
        )
        gravityMenu = NSMenu()
        gravityItem = NSMenuItem(
            title: String(localized: "menu.video_gravity"),
            action: nil,
            keyEquivalent: ""
        )
        loginItem = NSMenuItem(
            title: String(localized: "menu.launch_at_login"),
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        versionItem = NSMenuItem()
        quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "play.rectangle.fill",
                accessibilityDescription: "VideoWallpaper"
            )
        }

        loginItemEnabled = SMAppService.mainApp.status == .enabled

        configureMenuItems()
        buildStaticMenus()
        refreshPlaylistSection()
        refreshSelectionStates()
        refreshLoginState()
        statusItem.menu = menu
    }

    private func configureMenuItems() {
        summaryItem.isEnabled = false
        currentItem.isEnabled = false
        currentItem.isHidden = true

        [addItem, editItem, previousItem, nextItem, clearItem, loginItem, quitItem].forEach {
            $0.target = self
        }
        versionItem.isEnabled = false
        versionItem.title = String(
            format: String(localized: "menu.version"),
            locale: .current,
            BuildInfo.version
        )

        dimItem.submenu = dimMenu
        powerItem.submenu = powerMenu
        gravityItem.submenu = gravityMenu
    }

    private func buildStaticMenus() {
        menu.removeAllItems()
        menu.addItem(summaryItem)
        menu.addItem(currentItem)
        menu.addItem(.separator())
        menu.addItem(addItem)
        menu.addItem(editItem)
        menu.addItem(previousItem)
        menu.addItem(nextItem)
        menu.addItem(clearItem)
        menu.addItem(playlistSeparator)
        menu.addItem(dimItem)
        menu.addItem(powerItem)
        menu.addItem(gravityItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        populateSelectionMenu(
            dimMenu,
            with: DimLevel.allCases.map {
                SelectionMenuEntry(
                    title: $0.label,
                    rawValue: $0.rawValue,
                    action: #selector(selectDimLevel(_:))
                )
            }
        )
        populateSelectionMenu(
            powerMenu,
            with: PowerSavingMode.allCases.map {
                SelectionMenuEntry(
                    title: $0.label,
                    rawValue: $0.rawValue,
                    action: #selector(selectPowerSavingMode(_:))
                )
            }
        )
        populateSelectionMenu(
            gravityMenu,
            with: VideoGravity.allCases.map {
                SelectionMenuEntry(
                    title: $0.label,
                    rawValue: $0.rawValue,
                    action: #selector(selectVideoGravity(_:))
                )
            }
        )
    }

    private func populateSelectionMenu(
        _ menu: NSMenu,
        with entries: [SelectionMenuEntry]
    ) {
        menu.removeAllItems()
        for entry in entries {
            let item = NSMenuItem(title: entry.title, action: entry.action, keyEquivalent: "")
            item.target = self
            item.representedObject = entry.rawValue
            menu.addItem(item)
        }
    }

    private var hasPlaylist: Bool {
        guard let playlistSummary else { return false }
        return playlistSummary.itemCount > 0
    }

    private func refreshPlaylistSection() {
        guard let playlistSummary else {
            summaryItem.title = String(localized: "menu.playlist.summary.empty")
            currentItem.isHidden = true
            playlistSeparator.isHidden = true
            refreshPlaylistActions()
            return
        }

        summaryItem.title = playlistSummaryTitle(for: playlistSummary)

        if let currentDisplayName = playlistSummary.currentDisplayName {
            currentItem.title = String(
                format: String(localized: "menu.playlist.current"),
                locale: .current,
                currentDisplayName
            )
            currentItem.isHidden = false
        } else {
            currentItem.isHidden = true
        }

        playlistSeparator.isHidden = !hasPlaylist
        refreshPlaylistActions()
    }

    private func refreshPlaylistActions() {
        editItem.isEnabled = hasPlaylist
        previousItem.isEnabled = hasPlaylist
        nextItem.isEnabled = hasPlaylist
        clearItem.isEnabled = hasPlaylist
    }

    private func playlistSummaryTitle(for summary: PlaylistSummary) -> String {
        if summary.itemCount == 1 {
            return String(localized: "menu.playlist.summary.single")
        }

        return String(
            format: String(localized: "menu.playlist.summary.multiple"),
            locale: .current,
            summary.itemCount
        )
    }

    @objc private func selectDimLevel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let level = DimLevel(rawValue: rawValue) else { return }
        level.save()
        onDimLevelChanged?(level.opacity)
        updateSelectionStates(in: dimMenu, selectedRawValue: level.rawValue)
    }

    @objc private func selectPowerSavingMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PowerSavingMode(rawValue: rawValue) else { return }
        mode.save()
        onPowerSavingModeChanged?()
        updateSelectionStates(in: powerMenu, selectedRawValue: mode.rawValue)
    }

    @objc private func selectVideoGravity(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let gravity = VideoGravity(rawValue: rawValue) else { return }
        gravity.save()
        onVideoGravityChanged?(gravity)
        updateSelectionStates(in: gravityMenu, selectedRawValue: gravity.rawValue)
    }

    @objc private func toggleLoginItem() {
        do {
            if loginItemEnabled {
                try SMAppService.mainApp.unregister()
                loginItemEnabled = false
            } else {
                try SMAppService.mainApp.register()
                loginItemEnabled = true
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.login_item_failed.title")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshLoginState()
    }
}

private extension StatusMenuController {
    @objc func addVideosAction() {
        onAddVideos?()
    }

    @objc func editPlaylistAction() {
        onEditPlaylist?()
    }

    @objc func previousPlaylistAction() {
        onPrevious?()
    }

    @objc func nextPlaylistAction() {
        onNext?()
    }

    @objc func clearPlaylistAction() {
        onClear?()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func refreshSelectionStates() {
        updateSelectionStates(in: dimMenu, selectedRawValue: DimLevel.saved.rawValue)
        updateSelectionStates(in: powerMenu, selectedRawValue: PowerSavingMode.saved.rawValue)
        updateSelectionStates(in: gravityMenu, selectedRawValue: VideoGravity.saved.rawValue)
    }

    func updateSelectionStates(in menu: NSMenu, selectedRawValue: String) {
        for item in menu.items {
            item.state = (item.representedObject as? String) == selectedRawValue ? .on : .off
        }
    }

    func refreshLoginState() {
        loginItem.state = loginItemEnabled ? .on : .off
    }
}

extension StatusMenuController {
    var fixedMenuItemIdentifiersForTesting: [ObjectIdentifier] {
        [
            ObjectIdentifier(summaryItem),
            ObjectIdentifier(addItem),
            ObjectIdentifier(editItem),
            ObjectIdentifier(previousItem),
            ObjectIdentifier(nextItem),
            ObjectIdentifier(clearItem),
            ObjectIdentifier(dimItem),
            ObjectIdentifier(powerItem),
            ObjectIdentifier(gravityItem),
            ObjectIdentifier(loginItem),
            ObjectIdentifier(versionItem),
            ObjectIdentifier(quitItem)
        ]
    }

    var summaryTitleForTesting: String? {
        summaryItem.title
    }

    var currentTitleForTesting: String? {
        currentItem.isHidden ? nil : currentItem.title
    }
}
