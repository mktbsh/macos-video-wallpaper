import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct DimLevelTests {

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
        UserDefaults.standard.removeObject(forKey: "wallpaperDimLevel")
        #expect(DimLevel.saved == .none)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: "wallpaperDimLevel") }
        DimLevel.dark.save()
        #expect(DimLevel.saved == .dark)
    }
}
