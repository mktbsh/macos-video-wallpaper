import AppKit
import Foundation
import Testing
@testable import VideoWallpaper

/// AppDelegate のオーケストレーション経路（動画選択 / 解除 / 画面トグル / menu state 構築）を
/// InMemoryDisplayWallpaperStore で検証する。
@Suite(.serialized) @MainActor
struct AppDelegateWallpaperStoreTests {

    // MARK: - handleVideoSelected

    @Test func video_selected_saves_to_store_and_loads_controller() throws {
        let context = try TestContext()

        context.appDelegate.handleVideoSelected(context.videoURL, for: context.displayId)

        #expect(context.store.videos[context.displayId] == context.videoURL)
        #expect(context.controller.loadedURLs.contains(context.videoURL))

        let state = try #require(context.menuState())
        #expect(state.errorMessage == nil)
        #expect(state.currentVideoName == context.videoURL.lastPathComponent)
    }

    @Test func video_selected_reports_error_when_save_fails() throws {
        let context = try TestContext()
        context.store.saveShouldFail = true

        context.appDelegate.handleVideoSelected(context.videoURL, for: context.displayId)

        let state = try #require(context.menuState())
        #expect(state.errorMessage != nil)
        #expect(
            state.errorMessage
                == WallpaperError.bookmarkSaveFailed(context.displayId).localizedMessage
        )
    }

    @Test func video_dropped_on_controller_flows_through_production_wiring() throws {
        let context = try TestContext()

        context.controller.onVideoDropped?(context.videoURL, context.displayId)

        #expect(context.store.videos[context.displayId] == context.videoURL)
        #expect(context.controller.loadedURLs.contains(context.videoURL))
    }

    // MARK: - loadVideoForDisplay

    @Test func load_clears_video_without_error_when_nothing_saved() throws {
        let context = try TestContext()
        let clearsBefore = context.controller.clearVideoCallCount

        context.appDelegate.loadVideoForDisplay(context.displayId, on: context.controller)

        #expect(context.controller.clearVideoCallCount == clearsBefore + 1)
        let state = try #require(context.menuState())
        #expect(state.errorMessage == nil)
    }

    @Test func load_sets_resolve_error_and_clears_video_when_resolve_fails() throws {
        let context = try TestContext()
        context.store.resolveOverrides[context.displayId] = .resolveFailed
        let clearsBefore = context.controller.clearVideoCallCount

        context.appDelegate.loadVideoForDisplay(context.displayId, on: context.controller)

        #expect(context.controller.clearVideoCallCount == clearsBefore + 1)
        let state = try #require(context.menuState())
        #expect(
            state.errorMessage
                == WallpaperError.bookmarkResolveFailed(context.displayId).localizedMessage
        )
    }

    // MARK: - buildDisplayStates

    @Test func display_states_reflect_resolve_failure_as_error_message() throws {
        let context = try TestContext()
        context.store.resolveOverrides[context.displayId] = .resolveFailed

        // resolveFailed を観測してエラー状態を立てる
        context.appDelegate.loadVideoForDisplay(context.displayId, on: context.controller)
        let state = try #require(context.menuState())

        #expect(state.errorMessage != nil)
        #expect(state.currentVideoName == nil)
        #expect(state.isEnabled)
    }

    // MARK: - handleVideoCleared

    @Test func video_cleared_clears_store_error_and_menu_state() throws {
        let context = try TestContext()
        context.appDelegate.handleVideoSelected(context.videoURL, for: context.displayId)

        context.appDelegate.handleVideoCleared(for: context.displayId)

        #expect(context.store.videos[context.displayId] == nil)
        #expect(context.store.clearCallCount >= 1)
        let state = try #require(context.menuState())
        #expect(state.errorMessage == nil)
        #expect(state.currentVideoName == nil)
    }

    // MARK: - handleDisplayToggled

    @Test func display_toggled_off_persists_flag_and_invalidates_controller() throws {
        let context = try TestContext()
        #expect(context.controller.invalidateCallCount == 0)

        context.appDelegate.handleDisplayToggled(context.displayId, enabled: false)

        #expect(context.store.enabled[context.displayId] == false)
        #expect(context.controller.invalidateCallCount == 1)
    }

    // MARK: - Helpers

    @MainActor
    private struct TestContext {
        let appDelegate: AppDelegate
        let store: InMemoryDisplayWallpaperStore
        let controller: FakeWallpaperWindowController
        let displayId: DisplayIdentifier
        let videoURL: URL

        init() throws {
            let screen = try #require(NSScreen.screens.first)
            displayId = try #require(screen.displayIdentifier)
            store = InMemoryDisplayWallpaperStore()
            controller = FakeWallpaperWindowController()
            videoURL = URL(fileURLWithPath: "/tmp/wallpaper-test-\(UUID().uuidString).mp4")
            appDelegate = AppDelegate(
                screenProvider: { [screen] },
                controllerFactory: { [controller] _ in controller },
                isOnBatteryProvider: { false },
                displayWallpaperStore: store
            )
            appDelegate.applicationDidFinishLaunching(
                Notification(name: Notification.Name("test"))
            )
        }

        func menuState() -> DisplayMenuState? {
            appDelegate.buildDisplayStates().first { $0.displayIdentifier == displayId }
        }
    }
}
