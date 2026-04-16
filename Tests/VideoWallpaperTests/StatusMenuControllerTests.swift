import Foundation
import Testing
@testable import VideoWallpaper

@MainActor
struct StatusMenuControllerTests {

    @Test func rebuild_menu_preserves_fixed_menu_items() {
        let controller = StatusMenuController()
        let initialIdentifiers = controller.fixedMenuItemIdentifiersForTesting

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: "ocean.mp4"
            )
        ]

        #expect(controller.fixedMenuItemIdentifiersForTesting == initialIdentifiers)
    }

    @Test func display_section_adds_items_for_enabled_display() {
        let controller = StatusMenuController()
        let emptyCount = controller.menuItemCountForTesting

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: "ocean.mp4"
            )
        ]

        // Enabled display adds: separator, header, toggle, current, select, clear = 6
        #expect(controller.menuItemCountForTesting == emptyCount + 6)
    }

    @Test func disabled_display_shows_only_header_and_toggle() {
        let controller = StatusMenuController()
        let emptyCount = controller.menuItemCountForTesting

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "External Display",
                isEnabled: false,
                currentVideoName: nil
            )
        ]

        // Disabled display adds: separator, header, toggle = 3
        #expect(controller.menuItemCountForTesting == emptyCount + 3)
    }

    @Test func multiple_displays_each_add_section() {
        let controller = StatusMenuController()
        let emptyCount = controller.menuItemCountForTesting

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: nil
            ),
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 4, model: 5, serial: 6),
                screenName: "External Display",
                isEnabled: true,
                currentVideoName: "city.mp4"
            )
        ]

        // Two enabled displays: 2 × (separator + header + toggle + current + select + clear) = 12
        #expect(controller.menuItemCountForTesting == emptyCount + 12)
    }

    @Test func error_message_adds_extra_menu_item() {
        let controller = StatusMenuController()
        let emptyCount = controller.menuItemCountForTesting

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: "ocean.mp4",
                errorMessage: "Video file not found"
            )
        ]

        // Enabled display with error adds: separator, header, toggle, error, current, select, clear = 7
        #expect(controller.menuItemCountForTesting == emptyCount + 7)
    }

    @Test func no_error_uses_normal_icon() {
        let controller = StatusMenuController()

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: "ocean.mp4"
            )
        ]

        #expect(controller.statusIconNameForTesting == "play.rectangle.fill")
    }

    @Test func error_state_uses_warning_icon() {
        let controller = StatusMenuController()

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: nil,
                errorMessage: "Video file not found"
            )
        ]

        #expect(controller.statusIconNameForTesting == "exclamationmark.triangle.fill")
    }

    @Test func icon_reverts_to_normal_after_error_clears() {
        let controller = StatusMenuController()

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: nil,
                errorMessage: "Video file not found"
            )
        ]

        #expect(controller.statusIconNameForTesting == "exclamationmark.triangle.fill")

        controller.displayStates = [
            DisplayMenuState(
                displayIdentifier: DisplayIdentifier(vendor: 1, model: 2, serial: 3),
                screenName: "Built-in Display",
                isEnabled: true,
                currentVideoName: "ocean.mp4"
            )
        ]

        #expect(controller.statusIconNameForTesting == "play.rectangle.fill")
    }

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
