import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct PowerSavingModeTests {

    // MARK: - CaseIterable

    @Test func allCases_has_three_elements() {
        #expect(PowerSavingMode.allCases.count == 3)
    }

    // MARK: - rawValue (stability guards for UserDefaults persistence)

    @Test func rawValues_are_stable() {
        #expect(PowerSavingMode.never.rawValue == "never")
        #expect(PowerSavingMode.always.rawValue == "always")
        #expect(PowerSavingMode.battery.rawValue == "battery")
    }

    // MARK: - label

    @Test func all_labels_are_non_empty() {
        for mode in PowerSavingMode.allCases {
            #expect(!mode.label.isEmpty)
        }
    }

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
        UserDefaults.standard.removeObject(forKey: PowerSavingMode.storageKey)
        #expect(PowerSavingMode.saved == .never)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: PowerSavingMode.storageKey) }
        PowerSavingMode.always.save()
        #expect(PowerSavingMode.saved == .always)
    }
}
