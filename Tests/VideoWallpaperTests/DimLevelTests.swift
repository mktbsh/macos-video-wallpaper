import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct DimLevelTests {

    // MARK: - CaseIterable

    @Test func allCases_has_three_elements() {
        #expect(DimLevel.allCases.count == 3)
    }

    // MARK: - rawValue (stability guards for UserDefaults persistence)

    @Test func rawValues_are_stable() {
        #expect(DimLevel.none.rawValue == "none")
        #expect(DimLevel.slight.rawValue == "slight")
        #expect(DimLevel.dark.rawValue == "dark")
    }

    // MARK: - label

    @Test func none_label_is_localized_dim_level_none() {
        #expect(DimLevel.none.label == localizedString("dim_level.none"))
    }

    @Test func slight_label_is_localized_dim_level_slight() {
        #expect(DimLevel.slight.label == localizedString("dim_level.slight"))
    }

    @Test func dark_label_is_localized_dim_level_dark() {
        #expect(DimLevel.dark.label == localizedString("dim_level.dark"))
    }

    // MARK: - opacity

    @Test func none_opacity_is_zero() {
        #expect(DimLevel.none.opacity == 0.0)
    }

    @Test func slight_opacity_is_point_three() {
        #expect(DimLevel.slight.opacity == 0.3)
    }

    @Test func dark_opacity_is_point_six() {
        #expect(DimLevel.dark.opacity == 0.6)
    }

    // MARK: - saved / save()

    @Test func saved_defaults_to_none_when_no_value_stored() {
        UserDefaults.standard.removeObject(forKey: DimLevel.storageKey)
        #expect(DimLevel.saved == .none)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: DimLevel.storageKey) }
        DimLevel.dark.save()
        #expect(DimLevel.saved == .dark)
    }

    @Test func saved_defaults_to_none_when_unknown_value_stored() {
        defer { UserDefaults.standard.removeObject(forKey: DimLevel.storageKey) }
        UserDefaults.standard.set("unknown_level", forKey: DimLevel.storageKey)
        #expect(DimLevel.saved == .none)
    }

    private func localizedString(_ key: String) -> String {
        Bundle(for: AppDelegate.self).localizedString(forKey: key, value: nil, table: nil)
    }
}
