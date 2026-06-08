import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct PowerSavingModeTests {

    // MARK: - shouldPause

    @Test func never_never_pauses() {
        #expect(PowerSavingMode.never.shouldPause(isOnBattery: false) == false)
        #expect(PowerSavingMode.never.shouldPause(isOnBattery: true) == false)
    }

    @Test func always_always_pauses() {
        #expect(PowerSavingMode.always.shouldPause(isOnBattery: false) == true)
        #expect(PowerSavingMode.always.shouldPause(isOnBattery: true) == true)
    }

    @Test func battery_pauses_only_on_battery() {
        #expect(PowerSavingMode.battery.shouldPause(isOnBattery: true) == true)
        #expect(PowerSavingMode.battery.shouldPause(isOnBattery: false) == false)
    }

    // MARK: - saved / save()

    @Test func saved_defaults_to_never_when_no_value_stored() {
        UserDefaults.standard.removeObject(forKey: "powerSavingMode")
        #expect(PowerSavingMode.saved == .never)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: "powerSavingMode") }
        PowerSavingMode.always.save()
        #expect(PowerSavingMode.saved == .always)
    }
}
