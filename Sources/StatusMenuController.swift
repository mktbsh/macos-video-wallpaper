import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class StatusMenuController {

    var onVideoURLChanged: ((URL) -> Void)?
    var onScreenTargetChanged: (() -> Void)?
    var onDimLevelChanged: ((CGFloat) -> Void)?
    var onPowerSavingModeChanged: (() -> Void)?
    var onVideoGravityChanged: ((VideoGravity) -> Void)?
    var onVideoCleared: (() -> Void)?

    var currentVideoName: String? {
        didSet { buildMenu() }
    }

    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private var loginItemEnabled: Bool = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "play.rectangle.fill",
                accessibilityDescription: "VideoWallpaper"
            )
        }

        loginItemEnabled = SMAppService.mainApp.status == .enabled

        buildMenu()
        statusItem.menu = menu
    }

    private func buildMenu() {
        menu.removeAllItems()

        let infoItem = NSMenuItem()
        infoItem.title = currentVideoName.map {
            String(format: String(localized: "menu.wallpaper.current"), locale: .current, $0)
        } ?? String(localized: "menu.wallpaper.unset")
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(.separator())

        let selectItem = NSMenuItem(
            title: String(localized: "menu.video.select"),
            action: #selector(selectVideo),
            keyEquivalent: ""
        )
        selectItem.target = self
        menu.addItem(selectItem)

        if currentVideoName != nil {
            let clearItem = NSMenuItem(
                title: String(localized: "menu.wallpaper.clear"),
                action: #selector(clearVideoAction),
                keyEquivalent: ""
            )
            clearItem.target = self
            menu.addItem(clearItem)
        }

        let screenMenu = NSMenu()
        let currentTarget = ScreenTarget.saved
        for target in ScreenTarget.allCases {
            let item = NSMenuItem(
                title: target.label,
                action: #selector(selectScreenTarget(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = target.rawValue
            item.state = target == currentTarget ? .on : .off
            screenMenu.addItem(item)
        }
        let screenItem = NSMenuItem(
            title: String(localized: "menu.screen_target"),
            action: nil,
            keyEquivalent: ""
        )
        screenItem.submenu = screenMenu
        menu.addItem(screenItem)

        let dimMenu = NSMenu()
        let currentDim = DimLevel.saved
        for level in DimLevel.allCases {
            let item = NSMenuItem(
                title: level.label,
                action: #selector(selectDimLevel(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = level.rawValue
            item.state = level == currentDim ? .on : .off
            dimMenu.addItem(item)
        }
        let dimItem = NSMenuItem(
            title: String(localized: "menu.dim_level"),
            action: nil,
            keyEquivalent: ""
        )
        dimItem.submenu = dimMenu
        menu.addItem(dimItem)

        let powerMenu = NSMenu()
        let currentMode = PowerSavingMode.saved
        for mode in PowerSavingMode.allCases {
            let item = NSMenuItem(
                title: mode.label,
                action: #selector(selectPowerSavingMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentMode ? .on : .off
            powerMenu.addItem(item)
        }
        let powerItem = NSMenuItem(
            title: String(localized: "menu.power_saving"),
            action: nil,
            keyEquivalent: ""
        )
        powerItem.submenu = powerMenu
        menu.addItem(powerItem)

        let gravityMenu = NSMenu()
        let currentGravity = VideoGravity.saved
        for gravity in VideoGravity.allCases {
            let item = NSMenuItem(
                title: gravity.label,
                action: #selector(selectVideoGravity(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = gravity.rawValue
            item.state = gravity == currentGravity ? .on : .off
            gravityMenu.addItem(item)
        }
        let gravityItem = NSMenuItem(
            title: String(localized: "menu.video_gravity"),
            action: nil,
            keyEquivalent: ""
        )
        gravityItem.submenu = gravityMenu
        menu.addItem(gravityItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: String(localized: "menu.launch_at_login"),
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let versionItem = NSMenuItem()
        versionItem.title = String(
            format: String(localized: "menu.version"),
            locale: .current,
            BuildInfo.version
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectVideo() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "panel.select_video.title")
        // UTType(filenameExtension:) is used for m4v because .mpeg4Movie does not cover it
        let m4vType = UTType(filenameExtension: "m4v") ?? .mpeg4Movie
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, m4vType]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        VideoFileValidator.saveBookmark(for: url)
        currentVideoName = url.lastPathComponent
        onVideoURLChanged?(url)
    }

    @objc private func clearVideoAction() {
        // clearBookmark() は UserDefaults のエントリを削除するだけ。
        // セキュリティスコープアクセストークンは生きたままなので、
        // 次に onVideoCleared?() で clearVideo() が呼ばれるまで安全にアクセスできる。
        VideoFileValidator.clearBookmark()
        onVideoCleared?()
        currentVideoName = nil  // didSet で buildMenu() をトリガー
    }

    @objc private func selectScreenTarget(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let target = ScreenTarget(rawValue: rawValue) else { return }
        target.save()
        onScreenTargetChanged?()
        buildMenu()
    }

    @objc private func selectDimLevel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let level = DimLevel(rawValue: rawValue) else { return }
        level.save()
        onDimLevelChanged?(level.opacity)
        buildMenu()
    }

    @objc private func selectPowerSavingMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PowerSavingMode(rawValue: rawValue) else { return }
        mode.save()
        onPowerSavingModeChanged?()
        buildMenu()
    }

    @objc private func selectVideoGravity(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let gravity = VideoGravity(rawValue: rawValue) else { return }
        gravity.save()
        onVideoGravityChanged?(gravity)
        buildMenu()
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
        buildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
