import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

struct DisplayMenuState: Equatable {
    let displayIdentifier: DisplayIdentifier
    let screenName: String
    let isEnabled: Bool
    let currentVideoName: String?
}

private struct SelectionMenuEntry {
    let title: String
    let rawValue: String
    let action: Selector
}

@MainActor
final class StatusMenuController {

    var onVideoURLChanged: ((URL, DisplayIdentifier) -> Void)?
    var onVideoCleared: ((DisplayIdentifier) -> Void)?
    var onDisplayToggled: ((DisplayIdentifier, Bool) -> Void)?
    var onDimLevelChanged: ((CGFloat) -> Void)?
    var onPowerSavingModeChanged: (() -> Void)?
    var onVideoGravityChanged: ((VideoGravity) -> Void)?

    var displayStates: [DisplayMenuState] = [] {
        didSet { rebuildMenu() }
    }

    private let statusItem: NSStatusItem
    private let menu: NSMenu
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
        dimMenu = NSMenu()
        dimItem = NSMenuItem(
            title: "☀ " + String(localized: "menu.dim_level"),
            action: nil,
            keyEquivalent: ""
        )
        powerMenu = NSMenu()
        powerItem = NSMenuItem(
            title: "🔋 " + String(localized: "menu.power_saving"),
            action: nil,
            keyEquivalent: ""
        )
        gravityMenu = NSMenu()
        gravityItem = NSMenuItem(
            title: "📐 " + String(localized: "menu.video_gravity"),
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
        populateSubmenus()
        rebuildMenu()
        refreshSelectionStates()
        refreshLoginState()
        statusItem.menu = menu
    }

    private func configureMenuItems() {
        [loginItem, quitItem].forEach { $0.target = self }

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

    private func populateSubmenus() {
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

    private func rebuildMenu() {
        menu.removeAllItems()

        menu.addItem(versionItem)
        menu.addItem(.separator())

        menu.addItem(dimItem)
        menu.addItem(gravityItem)
        menu.addItem(powerItem)

        for state in displayStates {
            menu.addItem(.separator())
            addDisplaySection(for: state)
        }

        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    private func addDisplaySection(for state: DisplayMenuState) {
        let header = NSMenuItem(
            title: "🖥 " + state.screenName,
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        let toggle = NSMenuItem(
            title: String(localized: "menu.display.show_wallpaper"),
            action: #selector(toggleDisplay(_:)),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.representedObject = state.displayIdentifier
        toggle.state = state.isEnabled ? .on : .off
        toggle.indentationLevel = 1
        menu.addItem(toggle)

        guard state.isEnabled else { return }

        if let videoName = state.currentVideoName {
            let currentItem = NSMenuItem(
                title: String(
                    format: String(localized: "menu.wallpaper.current"),
                    locale: .current,
                    videoName
                ),
                action: nil,
                keyEquivalent: ""
            )
            currentItem.isEnabled = false
            currentItem.indentationLevel = 1
            menu.addItem(currentItem)
        } else {
            let unsetItem = NSMenuItem(
                title: String(localized: "menu.wallpaper.unset"),
                action: nil,
                keyEquivalent: ""
            )
            unsetItem.isEnabled = false
            unsetItem.indentationLevel = 1
            menu.addItem(unsetItem)
        }

        let selectItem = NSMenuItem(
            title: String(localized: "menu.video.select"),
            action: #selector(selectVideo(_:)),
            keyEquivalent: ""
        )
        selectItem.target = self
        selectItem.representedObject = state.displayIdentifier
        selectItem.indentationLevel = 1
        menu.addItem(selectItem)

        let clearItem = NSMenuItem(
            title: String(localized: "menu.wallpaper.clear"),
            action: #selector(clearWallpaper(_:)),
            keyEquivalent: ""
        )
        clearItem.target = self
        clearItem.representedObject = state.displayIdentifier
        clearItem.indentationLevel = 1
        menu.addItem(clearItem)
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let displayId = sender.representedObject as? DisplayIdentifier else { return }
        let newState = sender.state != .on
        onDisplayToggled?(displayId, newState)
    }

    @objc private func selectVideo(_ sender: NSMenuItem) {
        guard let displayId = sender.representedObject as? DisplayIdentifier else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "m4v") ?? .movie,
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard VideoFileValidator.isSupported(extension: url.pathExtension) else { return }

        onVideoURLChanged?(url, displayId)
    }

    @objc private func clearWallpaper(_ sender: NSMenuItem) {
        guard let displayId = sender.representedObject as? DisplayIdentifier else { return }
        onVideoCleared?(displayId)
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
            ObjectIdentifier(versionItem),
            ObjectIdentifier(dimItem),
            ObjectIdentifier(powerItem),
            ObjectIdentifier(gravityItem),
            ObjectIdentifier(loginItem),
            ObjectIdentifier(quitItem),
        ]
    }

    var menuItemCountForTesting: Int {
        menu.items.count
    }
}
