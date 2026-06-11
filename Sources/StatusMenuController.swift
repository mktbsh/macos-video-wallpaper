import Cocoa
import ServiceManagement

@MainActor
protocol LoginItemManaging {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

@MainActor
protocol StatusMenuErrorPresenting {
    func presentLoginItemError(_ error: Error)
}

@MainActor
struct MainAppLoginItemManager: LoginItemManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
struct AlertStatusMenuErrorPresenter: StatusMenuErrorPresenting {
    func presentLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.login_item_failed.title")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

/// 全ディスプレイ共通の壁紙状態（現在の動画名・エラー）。
struct WallpaperMenuState: Equatable {
    let currentVideoName: String?
    let errorMessage: String?

    init(currentVideoName: String? = nil, errorMessage: String? = nil) {
        self.currentVideoName = currentVideoName
        self.errorMessage = errorMessage
    }
}

private struct SelectionMenuEntry {
    let title: String
    let rawValue: String
    let action: Selector
}

@MainActor
final class StatusMenuController {

    var onVideoURLChanged: ((URL) -> Void)?
    var onVideoCleared: (() -> Void)?
    var onDimLevelChanged: ((CGFloat) -> Void)?
    var onPowerSavingModeChanged: (() -> Void)?
    var onVideoGravityChanged: ((VideoGravity) -> Void)?

    var wallpaperState: WallpaperMenuState = WallpaperMenuState() {
        didSet {
            guard wallpaperState != oldValue else { return }
            refreshWallpaperItems()
            updateStatusIcon()
        }
    }

    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let dimMenu: NSMenu
    private let dimItem: NSMenuItem
    private let powerMenu: NSMenu
    private let powerItem: NSMenuItem
    private let gravityMenu: NSMenu
    private let gravityItem: NSMenuItem
    private let errorItem: NSMenuItem
    private let currentVideoItem: NSMenuItem
    private let selectVideoItem: NSMenuItem
    private let clearWallpaperItem: NSMenuItem
    private let loginItem: NSMenuItem
    private let versionItem: NSMenuItem
    private let quitItem: NSMenuItem
    private let loginItemManager: any LoginItemManaging
    private let errorPresenter: any StatusMenuErrorPresenting
    private var loginItemEnabled: Bool = false
    private(set) var currentIconName: String = "play.rectangle.fill"

    init(
        loginItemManager: any LoginItemManaging = MainAppLoginItemManager(),
        errorPresenter: any StatusMenuErrorPresenting = AlertStatusMenuErrorPresenter()
    ) {
        self.loginItemManager = loginItemManager
        self.errorPresenter = errorPresenter
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
        errorItem = NSMenuItem()
        currentVideoItem = NSMenuItem()
        selectVideoItem = NSMenuItem(
            title: String(localized: "menu.video.select"),
            action: #selector(selectVideo),
            keyEquivalent: ""
        )
        clearWallpaperItem = NSMenuItem(
            title: String(localized: "menu.wallpaper.clear"),
            action: #selector(clearWallpaper),
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

        loginItemEnabled = loginItemManager.isEnabled

        configureMenuItems()
        populateSubmenus()
        buildMenu()
        refreshWallpaperItems()
        refreshSelectionStates()
        refreshLoginState()
        updateStatusIcon()
        statusItem.menu = menu
    }

    private func configureMenuItems() {
        [loginItem, quitItem, selectVideoItem, clearWallpaperItem].forEach { $0.target = self }

        versionItem.isEnabled = false
        versionItem.title = String(
            format: String(localized: "menu.version"),
            locale: .current,
            BuildInfo.version
        )

        errorItem.isEnabled = false
        currentVideoItem.isEnabled = false

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

    /// メニュー構成は固定（per-display セクションはない）。項目参照を保持し、
    /// 状態変化では `refreshWallpaperItems()` で title / isHidden だけ差分更新する。
    private func buildMenu() {
        menu.removeAllItems()

        menu.addItem(versionItem)
        menu.addItem(.separator())

        menu.addItem(dimItem)
        menu.addItem(gravityItem)
        menu.addItem(powerItem)

        menu.addItem(.separator())
        menu.addItem(errorItem)
        menu.addItem(currentVideoItem)
        menu.addItem(selectVideoItem)
        menu.addItem(clearWallpaperItem)

        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    private func refreshWallpaperItems() {
        if let errorMessage = wallpaperState.errorMessage {
            errorItem.title = "⚠ " + errorMessage
            errorItem.isHidden = false
        } else {
            errorItem.isHidden = true
        }

        if let videoName = wallpaperState.currentVideoName {
            currentVideoItem.title = String(
                format: String(localized: "menu.wallpaper.current"),
                locale: .current,
                videoName
            )
        } else {
            currentVideoItem.title = String(localized: "menu.wallpaper.unset")
        }
    }

    private func updateStatusIcon() {
        let hasError = wallpaperState.errorMessage != nil
        currentIconName = hasError ? "exclamationmark.triangle.fill" : "play.rectangle.fill"
        let accessibilityLabel = String(localized: "status.accessibility.label")
        let accessibilityValue = String(localized: hasError
            ? "status.accessibility.value.error"
            : "status.accessibility.value.normal")
        let toolTip = String(localized: hasError ? "status.tooltip.error" : "status.tooltip.normal")

        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: currentIconName,
            accessibilityDescription: accessibilityLabel
        )
        button.setAccessibilityLabel(accessibilityLabel)
        button.setAccessibilityValue(accessibilityValue)
        button.toolTip = toolTip
    }

    @objc private func selectVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = VideoFileType.allowedUTTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard VideoFileType.isSupported(extension: url.pathExtension) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.unsupported_file.title")
            alert.informativeText = String(localized: "alert.unsupported_file.message")
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        onVideoURLChanged?(url)
    }

    @objc private func clearWallpaper() {
        onVideoCleared?()
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
                try loginItemManager.unregister()
                loginItemEnabled = false
            } else {
                try loginItemManager.register()
                loginItemEnabled = true
            }
        } catch {
            errorPresenter.presentLoginItemError(error)
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
            ObjectIdentifier(errorItem),
            ObjectIdentifier(currentVideoItem),
            ObjectIdentifier(selectVideoItem),
            ObjectIdentifier(clearWallpaperItem),
            ObjectIdentifier(loginItem),
            ObjectIdentifier(quitItem)
        ]
    }

    var menuItemCountForTesting: Int {
        menu.items.count
    }

    var menuItemIdentifiersForTesting: [ObjectIdentifier] {
        menu.items.map(ObjectIdentifier.init)
    }

    var errorItemIsHiddenForTesting: Bool {
        errorItem.isHidden
    }

    var errorItemTitleForTesting: String {
        errorItem.title
    }

    var currentVideoTitleForTesting: String {
        currentVideoItem.title
    }

    var statusIconNameForTesting: String {
        currentIconName
    }

    var statusButtonAccessibilityLabelForTesting: String? {
        statusItem.button?.accessibilityLabel()
    }

    var statusButtonAccessibilityValueForTesting: String? {
        statusItem.button?.accessibilityValue() as? String
    }

    var statusButtonToolTipForTesting: String? {
        statusItem.button?.toolTip
    }

    var loginItemStateForTesting: NSControl.StateValue {
        loginItem.state
    }

    func toggleLoginItemForTesting() {
        toggleLoginItem()
    }
}
