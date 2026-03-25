import Testing
import Foundation
@testable import VideoWallpaper

@Suite(.serialized) struct ScreenTargetTests {

    // MARK: - rawValue

    @Test func all_rawValue_is_all() {
        #expect(ScreenTarget.all.rawValue == "all")
    }

    @Test func builtIn_rawValue_is_builtin() {
        #expect(ScreenTarget.builtIn.rawValue == "builtin")
    }

    @Test func external_rawValue_is_external() {
        #expect(ScreenTarget.external.rawValue == "external")
    }

    @Test func unknown_rawValue_falls_back_to_all() {
        #expect(ScreenTarget(rawValue: "unknown") == nil)
    }

    // MARK: - CaseIterable

    @Test func allCases_has_three_elements() {
        #expect(ScreenTarget.allCases.count == 3)
    }

    // MARK: - label

    @Test func all_label_is_correct() {
        #expect(ScreenTarget.all.label == "すべての画面")
    }

    // MARK: - saved / save()

    @Test func saved_defaults_to_all_when_no_value_stored() {
        UserDefaults.standard.removeObject(forKey: "screenTarget")
        #expect(ScreenTarget.saved == .all)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: "screenTarget") }
        ScreenTarget.builtIn.save()
        #expect(ScreenTarget.saved == .builtIn)
    }
}
