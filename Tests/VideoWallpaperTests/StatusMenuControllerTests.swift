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
            ),
        ]

        #expect(controller.fixedMenuItemIdentifiersForTesting == initialIdentifiers)
    }
}
