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

    @Test func playlist_menu_actions_are_translated_for_both_locales() throws {
        #expect(try localizedString("menu.playlist.add_videos", locale: "en") == "Add Videos...")
        #expect(try localizedString("menu.playlist.add_videos", locale: "ja") == "動画を追加…")
        #expect(try localizedString("menu.playlist.edit", locale: "en") == "Edit Playlist...")
        #expect(try localizedString("menu.playlist.edit", locale: "ja") == "プレイリストを編集…")
    }

    @Test func playlist_editor_labels_are_translated_for_both_locales() throws {
        #expect(try localizedString("playlist_editor.display_name", locale: "en") == "Display Name")
        #expect(try localizedString("playlist_editor.display_name", locale: "ja") == "表示名")
        #expect(try localizedString("playlist_editor.use_full_video", locale: "en") == "Use Full Video")
        #expect(try localizedString("playlist_editor.use_full_video", locale: "ja") == "動画全体を使う")
    }

    private func localizedString(_ key: String, locale: String) throws -> String {
        let bundle = Bundle(for: AppDelegate.self)
        let path = try #require(bundle.path(forResource: locale, ofType: "lproj"))
        let localizedBundle = try #require(Bundle(path: path))
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
