import Testing
@testable import VideoWallpaper

@MainActor
struct StatusMenuControllerTests {

    @Test func playlist_summary_update_reuses_fixed_menu_items() {
        let controller = StatusMenuController()
        let initialIdentifiers = controller.fixedMenuItemIdentifiersForTesting

        controller.playlistSummary = PlaylistSummary(itemCount: 2, currentDisplayName: "foo.mov")

        #expect(controller.fixedMenuItemIdentifiersForTesting == initialIdentifiers)
        #expect(controller.summaryTitleForTesting?.contains("2") == true)
        #expect(controller.currentTitleForTesting?.contains("foo.mov") == true)
    }
}
