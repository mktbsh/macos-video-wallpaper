import AppKit
import Foundation
import Testing
@testable import VideoWallpaper

/// AppDelegate のグローバル壁紙オーケストレーション（動画選択 / 解除 / 全 controller 適用 /
/// menu state 構築）を InMemoryWallpaperVideoStore で検証する。
@Suite(.serialized) @MainActor
struct AppDelegateWallpaperStoreTests {

    // MARK: - handleVideoSelected

    @Test func video_selected_saves_to_store_and_loads_controller() throws {
        let context = try TestContext()

        context.appDelegate.handleVideoSelected(context.videoURL)

        #expect(context.store.video == context.videoURL)
        #expect(context.controller.loadedURLs.contains(context.videoURL))

        let state = context.appDelegate.buildWallpaperMenuState()
        #expect(state.errorMessage == nil)
        #expect(state.currentVideoName == context.videoURL.lastPathComponent)
    }

    @Test func video_selected_reports_error_when_save_fails() throws {
        let context = try TestContext()
        context.store.saveShouldFail = true

        context.appDelegate.handleVideoSelected(context.videoURL)

        let state = context.appDelegate.buildWallpaperMenuState()
        #expect(state.errorMessage == WallpaperError.bookmarkSaveFailed.localizedMessage)
    }

    @Test func video_dropped_on_controller_flows_through_production_wiring() throws {
        let context = try TestContext()

        context.controller.onVideoDropped?(context.videoURL)

        #expect(context.store.video == context.videoURL)
        #expect(context.controller.loadedURLs.contains(context.videoURL))
    }

    // MARK: - handleVideoCleared

    @Test func video_cleared_clears_store_error_and_menu_state() throws {
        let context = try TestContext()
        context.appDelegate.handleVideoSelected(context.videoURL)

        context.appDelegate.handleVideoCleared()

        #expect(context.store.video == nil)
        #expect(context.store.clearCallCount >= 1)
        let state = context.appDelegate.buildWallpaperMenuState()
        #expect(state.errorMessage == nil)
        #expect(state.currentVideoName == nil)
    }

    // MARK: - applyGlobalVideo（全 controller に同一適用）

    @Test func apply_resolved_video_loads_all_controllers_with_same_url() throws {
        let context = try TestContext()
        let url = URL(fileURLWithPath: "/tmp/global-\(UUID().uuidString).mp4")
        context.store.video = url

        let firstController = FakeWallpaperWindowController()
        let secondController = FakeWallpaperWindowController()
        context.appDelegate.applyGlobalVideo(to: [firstController, secondController])

        #expect(firstController.loadedURLs == [url])
        #expect(secondController.loadedURLs == [url])
    }

    @Test func apply_resolveFailed_sets_error_and_clears_all_controllers() throws {
        let context = try TestContext()
        context.store.resolveOverride = .resolveFailed

        let firstController = FakeWallpaperWindowController()
        let secondController = FakeWallpaperWindowController()
        context.appDelegate.applyGlobalVideo(to: [firstController, secondController])

        #expect(firstController.clearVideoCallCount == 1)
        #expect(secondController.clearVideoCallCount == 1)
        let state = context.appDelegate.buildWallpaperMenuState()
        #expect(state.errorMessage == WallpaperError.bookmarkResolveFailed.localizedMessage)
    }

    @Test func apply_noVideo_clears_all_controllers_without_error() throws {
        let context = try TestContext()

        let firstController = FakeWallpaperWindowController()
        let secondController = FakeWallpaperWindowController()
        context.appDelegate.applyGlobalVideo(to: [firstController, secondController])

        #expect(firstController.clearVideoCallCount == 1)
        #expect(secondController.clearVideoCallCount == 1)
        let state = context.appDelegate.buildWallpaperMenuState()
        #expect(state.errorMessage == nil)
    }

    // MARK: - Helpers

    @MainActor
    private struct TestContext {
        let appDelegate: AppDelegate
        let store: InMemoryWallpaperVideoStore
        let controller: FakeWallpaperWindowController
        let videoURL: URL

        init() throws {
            let screen = try #require(NSScreen.screens.first)
            store = InMemoryWallpaperVideoStore()
            controller = FakeWallpaperWindowController()
            videoURL = URL(fileURLWithPath: "/tmp/wallpaper-test-\(UUID().uuidString).mp4")
            appDelegate = AppDelegate(
                screenProvider: { [screen] },
                controllerFactory: { [controller] _ in controller },
                isOnBatteryProvider: { false },
                wallpaperVideoStore: store
            )
            appDelegate.applicationDidFinishLaunching(
                Notification(name: Notification.Name("test"))
            )
        }
    }
}
