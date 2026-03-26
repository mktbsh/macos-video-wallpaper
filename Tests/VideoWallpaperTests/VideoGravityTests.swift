import AVFoundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct VideoGravityTests {

    // MARK: - rawValue

    @Test func fill_rawValue_is_fill() {
        #expect(VideoGravity.fill.rawValue == "fill")
    }

    @Test func fit_rawValue_is_fit() {
        #expect(VideoGravity.fit.rawValue == "fit")
    }

    @Test func stretch_rawValue_is_stretch() {
        #expect(VideoGravity.stretch.rawValue == "stretch")
    }

    @Test func unknown_rawValue_returns_nil() {
        #expect(VideoGravity(rawValue: "unknown") == nil)
    }

    // MARK: - CaseIterable

    @Test func allCases_has_three_elements() {
        #expect(VideoGravity.allCases.count == 3)
    }

    // MARK: - label

    @Test func fill_label_is_cover() {
        #expect(VideoGravity.fill.label == localizedString("video_gravity.cover"))
    }

    @Test func fit_label_is_contain() {
        #expect(VideoGravity.fit.label == localizedString("video_gravity.contain"))
    }

    @Test func stretch_label_is_fill() {
        #expect(VideoGravity.stretch.label == localizedString("video_gravity.fill"))
    }

    // MARK: - avGravity

    @Test func fill_avGravity_is_resizeAspectFill() {
        #expect(VideoGravity.fill.avGravity == .resizeAspectFill)
    }

    @Test func fit_avGravity_is_resizeAspect() {
        #expect(VideoGravity.fit.avGravity == .resizeAspect)
    }

    @Test func stretch_avGravity_is_resize() {
        #expect(VideoGravity.stretch.avGravity == .resize)
    }

    // MARK: - saved / save()

    @Test func saved_defaults_to_fill_when_no_value_stored() {
        UserDefaults.standard.removeObject(forKey: "videoGravity")
        #expect(VideoGravity.saved == .fill)
    }

    @Test func save_and_restore_roundtrip() {
        defer { UserDefaults.standard.removeObject(forKey: "videoGravity") }
        VideoGravity.fit.save()
        #expect(VideoGravity.saved == .fit)
    }

    private func localizedString(_ key: String) -> String {
        Bundle(for: AppDelegate.self).localizedString(forKey: key, value: nil, table: nil)
    }
}
