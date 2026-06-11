import Foundation
import Testing
@testable import VideoWallpaper

@MainActor
struct StatusMenuControllerTests {

    // MARK: - 固定メニュー構成（per-display セクションはない）

    @Test func menu_structure_is_static_across_state_changes() {
        let controller = StatusMenuController()
        let initialIdentifiers = controller.menuItemIdentifiersForTesting

        controller.wallpaperState = WallpaperMenuState(
            currentVideoName: "ocean.mp4",
            errorMessage: "Video file not found"
        )

        // 状態変化でメニュー項目の構成・identity は変わらない（title/isHidden のみ差分更新）
        #expect(controller.menuItemIdentifiersForTesting == initialIdentifiers)
        #expect(controller.fixedMenuItemIdentifiersForTesting.allSatisfy { id in
            controller.menuItemIdentifiersForTesting.contains(id)
        })
    }

    @Test func assigning_same_state_does_not_rebuild_menu() {
        let controller = StatusMenuController()
        let state = WallpaperMenuState(currentVideoName: "ocean.mp4")
        controller.wallpaperState = state
        let initialIdentifiers = controller.menuItemIdentifiersForTesting

        controller.wallpaperState = state

        #expect(controller.menuItemIdentifiersForTesting == initialIdentifiers)
    }

    // MARK: - current video / error 項目

    @Test func current_video_title_reflects_state() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(currentVideoName: "ocean.mp4")

        #expect(
            controller.currentVideoTitleForTesting
                == String(format: String(localized: "menu.wallpaper.current"), locale: .current, "ocean.mp4")
        )
    }

    @Test func current_video_title_shows_unset_when_no_video() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(currentVideoName: nil)

        #expect(controller.currentVideoTitleForTesting == String(localized: "menu.wallpaper.unset"))
    }

    @Test func error_item_hidden_without_error() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(currentVideoName: "ocean.mp4")

        #expect(controller.errorItemIsHiddenForTesting)
    }

    @Test func error_item_shown_with_message() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(errorMessage: "Video file not found")

        #expect(!controller.errorItemIsHiddenForTesting)
        #expect(controller.errorItemTitleForTesting == "⚠ Video file not found")
    }

    // MARK: - status icon / accessibility

    @Test func no_error_uses_normal_icon() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(currentVideoName: "ocean.mp4")

        #expect(controller.statusIconNameForTesting == "play.rectangle.fill")
    }

    @Test func normal_status_item_exposes_accessibility_state() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(currentVideoName: "ocean.mp4")

        #expect(controller.statusButtonAccessibilityLabelForTesting == String(localized: "status.accessibility.label"))
        #expect(
            controller.statusButtonAccessibilityValueForTesting
                == String(localized: "status.accessibility.value.normal")
        )
        #expect(controller.statusButtonToolTipForTesting == String(localized: "status.tooltip.normal"))
    }

    @Test func error_state_uses_warning_icon() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(errorMessage: "Video file not found")

        #expect(controller.statusIconNameForTesting == "exclamationmark.triangle.fill")
    }

    @Test func error_status_item_exposes_accessibility_state() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(errorMessage: "Video file not found")

        #expect(controller.statusButtonAccessibilityLabelForTesting == String(localized: "status.accessibility.label"))
        #expect(
            controller.statusButtonAccessibilityValueForTesting
                == String(localized: "status.accessibility.value.error")
        )
        #expect(controller.statusButtonToolTipForTesting == String(localized: "status.tooltip.error"))
    }

    @Test func empty_state_uses_normal_icon() {
        let controller = StatusMenuController()

        #expect(controller.statusIconNameForTesting == "play.rectangle.fill")
    }

    @Test func icon_reverts_to_normal_after_error_clears() {
        let controller = StatusMenuController()

        controller.wallpaperState = WallpaperMenuState(errorMessage: "Video file not found")
        #expect(controller.statusIconNameForTesting == "exclamationmark.triangle.fill")

        controller.wallpaperState = WallpaperMenuState(currentVideoName: "ocean.mp4")
        #expect(controller.statusIconNameForTesting == "play.rectangle.fill")
    }

    // MARK: - login item

    @Test func login_item_state_reflects_injected_manager_on_init() {
        let manager = FakeLoginItemManager(isEnabled: true)
        let controller = StatusMenuController(
            loginItemManager: manager,
            errorPresenter: FakeStatusMenuErrorPresenter()
        )

        #expect(controller.loginItemStateForTesting == .on)
    }

    @Test func toggle_login_item_registers_when_disabled() {
        let manager = FakeLoginItemManager(isEnabled: false)
        let presenter = FakeStatusMenuErrorPresenter()
        let controller = StatusMenuController(
            loginItemManager: manager,
            errorPresenter: presenter
        )

        controller.toggleLoginItemForTesting()

        #expect(manager.registerCallCount == 1)
        #expect(manager.unregisterCallCount == 0)
        #expect(controller.loginItemStateForTesting == .on)
        #expect(presenter.presentedMessages.isEmpty)
    }

    @Test func toggle_login_item_unregisters_when_enabled() {
        let manager = FakeLoginItemManager(isEnabled: true)
        let presenter = FakeStatusMenuErrorPresenter()
        let controller = StatusMenuController(
            loginItemManager: manager,
            errorPresenter: presenter
        )

        controller.toggleLoginItemForTesting()

        #expect(manager.registerCallCount == 0)
        #expect(manager.unregisterCallCount == 1)
        #expect(controller.loginItemStateForTesting == .off)
        #expect(presenter.presentedMessages.isEmpty)
    }

    @Test func login_item_error_preserves_state_and_presents_alert() {
        let manager = FakeLoginItemManager(
            isEnabled: false,
            registerError: FakeLoginItemManager.SampleError.registrationFailed
        )
        let presenter = FakeStatusMenuErrorPresenter()
        let controller = StatusMenuController(
            loginItemManager: manager,
            errorPresenter: presenter
        )

        controller.toggleLoginItemForTesting()

        #expect(manager.registerCallCount == 1)
        #expect(controller.loginItemStateForTesting == .off)
        #expect(
            presenter.presentedMessages == [
                FakeLoginItemManager.SampleError.registrationFailed.localizedDescription
            ]
        )
    }

    @Test func unregister_error_preserves_on_state_and_presents_alert() {
        let manager = FakeLoginItemManager(
            isEnabled: true,
            unregisterError: FakeLoginItemManager.SampleError.registrationFailed
        )
        let presenter = FakeStatusMenuErrorPresenter()
        let controller = StatusMenuController(
            loginItemManager: manager,
            errorPresenter: presenter
        )

        controller.toggleLoginItemForTesting()

        #expect(manager.unregisterCallCount == 1)
        #expect(controller.loginItemStateForTesting == .on)
        #expect(presenter.presentedMessages.count == 1)
    }
}

@MainActor
private final class FakeLoginItemManager: LoginItemManaging {
    enum SampleError: Error, LocalizedError {
        case registrationFailed

        var errorDescription: String? {
            "Registration failed"
        }
    }

    private(set) var isEnabled: Bool
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private let registerError: Error?
    private let unregisterError: Error?

    init(
        isEnabled: Bool,
        registerError: Error? = nil,
        unregisterError: Error? = nil
    ) {
        self.isEnabled = isEnabled
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        isEnabled = true
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        isEnabled = false
    }
}

@MainActor
private final class FakeStatusMenuErrorPresenter: StatusMenuErrorPresenting {
    private(set) var presentedMessages: [String] = []

    func presentLoginItemError(_ error: any Error) {
        presentedMessages.append(error.localizedDescription)
    }
}
