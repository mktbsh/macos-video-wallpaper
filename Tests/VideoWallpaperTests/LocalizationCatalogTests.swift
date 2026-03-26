import Foundation
import Testing
@testable import VideoWallpaper

struct LocalizationCatalogTests {

    @Test func app_bundle_supports_english_and_japanese() throws {
        let bundle = try #require(Bundle(for: AppDelegate.self))
        #expect(bundle.localizations.contains("en"))
        #expect(bundle.localizations.contains("ja"))
    }

    @Test func menu_wallpaper_unset_is_translated_for_both_locales() throws {
        #expect(try localizedString("menu.wallpaper.unset", locale: "en") == "Wallpaper: Not Set")
        #expect(try localizedString("menu.wallpaper.unset", locale: "ja") == "壁紙: 未設定")
    }

    private func localizedString(_ key: String, locale: String) throws -> String {
        let bundle = Bundle(for: AppDelegate.self)
        let path = try #require(bundle.path(forResource: locale, ofType: "lproj"))
        let localizedBundle = try #require(Bundle(path: path))
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
