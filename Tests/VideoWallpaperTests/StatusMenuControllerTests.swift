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
}
