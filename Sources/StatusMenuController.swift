import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class StatusMenuController {

    var onVideoURLChanged: ((URL) -> Void)?
    var onScreenTargetChanged: (() -> Void)?
    var onDimLevelChanged: ((CGFloat) -> Void)?
    var onPowerSavingModeChanged: (() -> Void)?

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
        infoItem.title = currentVideoName.map { "壁紙: \($0)" } ?? "壁紙: 未設定"
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(.separator())

        let selectItem = NSMenuItem(
            title: "動画を選択…",
            action: #selector(selectVideo),
            keyEquivalent: ""
        )
        selectItem.target = self
        menu.addItem(selectItem)

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
        let screenItem = NSMenuItem(title: "対象画面", action: nil, keyEquivalent: "")
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
        let dimItem = NSMenuItem(title: "明るさ調整", action: nil, keyEquivalent: "")
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
        let powerItem = NSMenuItem(title: "低電力モード", action: nil, keyEquivalent: "")
        powerItem.submenu = powerMenu
        menu.addItem(powerItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "ログイン時に起動",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let versionItem = NSMenuItem()
        versionItem.title = "Version \(BuildInfo.version)"
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectVideo() {
        let panel = NSOpenPanel()
        panel.title = "壁紙動画を選択"
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
            alert.messageText = "ログイン起動の設定に失敗しました"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        buildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
