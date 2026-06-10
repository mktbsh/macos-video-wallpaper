import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) @MainActor
struct AppDelegateScreenLifecycleTests {

    @Test func screen_removed_invalidates_its_controller() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        var screens: [NSScreen] = [screen]
        let appDelegate = AppDelegate(
            screenProvider: { screens },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        #expect(controller.invalidateCallCount == 0)

        screens = []
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        #expect(controller.invalidateCallCount == 1)
    }

    @Test func setup_resumes_playback_when_not_on_battery() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.resumeCallCount >= 1)
        #expect(controller.pauseCallCount == 0)
    }

    @Test func setup_pauses_playback_when_power_saving_mode_is_always() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let originalValue = UserDefaults.standard.string(forKey: PowerSavingMode.storageKey)
        defer { UserDefaults.standard.set(originalValue, forKey: PowerSavingMode.storageKey) }
        UserDefaults.standard.set(PowerSavingMode.always.rawValue, forKey: PowerSavingMode.storageKey)

        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.pauseCallCount >= 1)
        #expect(controller.resumeCallCount == 0)
    }

    @Test func setup_applies_dim_level_and_video_gravity_on_new_controller() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.applyDimLevelCallCount >= 1)
        #expect(controller.applyVideoGravityCallCount >= 1)
    }

    @Test func setup_pauses_playback_when_power_saving_mode_is_battery_and_on_battery() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let originalValue = UserDefaults.standard.string(forKey: PowerSavingMode.storageKey)
        defer { UserDefaults.standard.set(originalValue, forKey: PowerSavingMode.storageKey) }
        UserDefaults.standard.set(PowerSavingMode.battery.rawValue, forKey: PowerSavingMode.storageKey)

        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { true }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.pauseCallCount >= 1)
        #expect(controller.resumeCallCount == 0)
    }

    @Test func setup_resumes_playback_when_power_saving_mode_is_battery_but_on_ac() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let originalValue = UserDefaults.standard.string(forKey: PowerSavingMode.storageKey)
        defer { UserDefaults.standard.set(originalValue, forKey: PowerSavingMode.storageKey) }
        UserDefaults.standard.set(PowerSavingMode.battery.rawValue, forKey: PowerSavingMode.storageKey)

        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        #expect(controller.resumeCallCount >= 1)
        #expect(controller.pauseCallCount == 0)
    }

    @Test func duplicate_display_identifiers_do_not_crash_setup() throws {
        // Two physical displays can resolve to the same DisplayIdentifier
        // (e.g. identical external monitors with serial 0). Building the
        // sort-order dictionary must not trap on the duplicate key.
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let appDelegate = AppDelegate(
            screenProvider: { [screen, screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        // Reaching here means setup completed without trapping.
        #expect(controller.applyVideoGravityCallCount >= 1)
    }

    @Test func terminate_invalidates_all_screen_controllers() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        #expect(controller.invalidateCallCount == 0)

        appDelegate.applicationWillTerminate(Notification(name: Notification.Name("test")))

        #expect(controller.invalidateCallCount == 1)
    }

    @Test func screen_reconfiguration_keeps_surviving_controller_alive_without_reload() throws {
        let screen = try #require(NSScreen.screens.first)
        let controller = FakeWallpaperWindowController()
        let appDelegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            isOnBatteryProvider: { false }
        )

        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        // No per-display bookmark → clearVideo is called; battery policy resumes
        let loadAfterSetup = controller.loadCallCount
        let clearAfterSetup = controller.clearVideoCallCount
        let resumeAfterSetup = controller.resumeCallCount
        let invalidateAfterSetup = controller.invalidateCallCount

        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Surviving controller is not touched on screen reconfiguration
        #expect(controller.loadCallCount == loadAfterSetup)
        #expect(controller.clearVideoCallCount == clearAfterSetup)
        #expect(controller.resumeCallCount == resumeAfterSetup)
        #expect(controller.invalidateCallCount == invalidateAfterSetup)
    }
}
