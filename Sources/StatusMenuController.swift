import Cocoa
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class StatusMenuController {

    var onVideoURLChanged: ((URL) -> Void)?

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

        let selectItem = NSMenuItem(
            title: "動画を選択…",
            action: #selector(selectVideo),
            keyEquivalent: ""
        )
        selectItem.target = self
        menu.addItem(selectItem)

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

        UserDefaults.standard.set(url.path, forKey: "videoFilePath")
        onVideoURLChanged?(url)
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
