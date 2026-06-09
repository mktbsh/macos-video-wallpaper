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

    @Test func never_label_is_localized_power_saving_mode_never() {
        #expect(PowerSavingMode.never.label == localizedString("power_saving_mode.never"))
    }

    @Test func always_label_is_localized_power_saving_mode_always() {
        #expect(PowerSavingMode.always.label == localizedString("power_saving_mode.always"))
    }

    @Test func battery_label_is_localized_power_saving_mode_battery() {
        #expect(PowerSavingMode.battery.label == localizedString("power_saving_mode.battery"))
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

    @Test func saved_defaults_to_never_when_unknown_value_stored() {
        defer { UserDefaults.standard.removeObject(forKey: PowerSavingMode.storageKey) }
        UserDefaults.standard.set("unknown_mode", forKey: PowerSavingMode.storageKey)
        #expect(PowerSavingMode.saved == .never)
    }

    private func localizedString(_ key: String) -> String {
        Bundle(for: AppDelegate.self).localizedString(forKey: key, value: nil, table: nil)
    }
}
