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

    @Test func playlist_summary_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("menu.playlist.summary.single", locale: "en") == "Wallpaper: 1 Video")
        #expect(try localizedString("menu.playlist.summary.single", locale: "ja") == "壁紙: 1 本の動画")
        #expect(try localizedString("menu.playlist.summary.multiple", locale: "en") == "Wallpaper: %lld Videos")
        #expect(try localizedString("menu.playlist.summary.multiple", locale: "ja") == "壁紙: %lld 本の動画")
    }

    @Test func playlist_editor_validation_message_is_translated_for_both_locales() throws {
        #expect(
            try localizedString("playlist_editor.validation.invalid_range", locale: "en")
                == "End time must be greater than start time."
        )
        #expect(
            try localizedString("playlist_editor.validation.invalid_range", locale: "ja")
                == "終了時間は開始時間より後である必要があります。"
        )
    }

    @Test func alert_login_item_failed_title_is_translated_for_both_locales() throws {
        #expect(
            try localizedString("alert.login_item_failed.title", locale: "en")
                == "Failed to Update Launch-at-Login Setting"
        )
        #expect(
            try localizedString("alert.login_item_failed.title", locale: "ja")
                == "ログイン起動の設定に失敗しました"
        )
    }

    @Test func error_messages_are_translated_for_both_locales() throws {
        #expect(
            try localizedString("error.bookmark_save_failed", locale: "en")
                == "Failed to save video bookmark"
        )
        #expect(
            try localizedString("error.bookmark_save_failed", locale: "ja")
                == "動画のブックマーク保存に失敗しました"
        )
        #expect(
            try localizedString("error.bookmark_resolve_failed", locale: "en")
                == "Video file not found"
        )
        #expect(
            try localizedString("error.bookmark_resolve_failed", locale: "ja")
                == "動画ファイルが見つかりません"
        )
        #expect(
            try localizedString("error.playback_failed", locale: "en")
                == "Cannot play video"
        )
        #expect(
            try localizedString("error.playback_failed", locale: "ja")
                == "動画を再生できません"
        )
    }

    @Test func alert_unsupported_file_keys_are_translated_for_both_locales() throws {
        #expect(
            try localizedString("alert.unsupported_file.title", locale: "en")
                == "Unsupported File Type"
        )
        #expect(
            try localizedString("alert.unsupported_file.title", locale: "ja")
                == "サポートされていないファイル形式です"
        )
        #expect(
            try localizedString("alert.unsupported_file.message", locale: "en")
                == "Please choose an MP4, MOV, or M4V video file."
        )
        #expect(
            try localizedString("alert.unsupported_file.message", locale: "ja")
                == "MP4、MOV、M4V 形式の動画ファイルを選択してください。"
        )
    }

    @Test func dim_level_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("dim_level.none", locale: "en") == "None")
        #expect(try localizedString("dim_level.none", locale: "ja") == "なし")
        #expect(try localizedString("dim_level.slight", locale: "en") == "Slightly Dim")
        #expect(try localizedString("dim_level.slight", locale: "ja") == "少し暗く")
        #expect(try localizedString("dim_level.dark", locale: "en") == "Dark")
        #expect(try localizedString("dim_level.dark", locale: "ja") == "暗く")
    }

    @Test func power_saving_mode_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("power_saving_mode.never", locale: "en") == "Never")
        #expect(try localizedString("power_saving_mode.never", locale: "ja") == "しない")
        #expect(try localizedString("power_saving_mode.battery", locale: "en") == "On Battery Only")
        #expect(try localizedString("power_saving_mode.battery", locale: "ja") == "バッテリー使用時のみ")
        #expect(try localizedString("power_saving_mode.always", locale: "en") == "Always")
        #expect(try localizedString("power_saving_mode.always", locale: "ja") == "常に")
    }

    @Test func video_gravity_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("video_gravity.cover", locale: "en") == "Cover")
        #expect(try localizedString("video_gravity.cover", locale: "ja") == "カバー")
        #expect(try localizedString("video_gravity.contain", locale: "en") == "Contain")
        #expect(try localizedString("video_gravity.contain", locale: "ja") == "全体表示")
        #expect(try localizedString("video_gravity.fill", locale: "en") == "Fill")
        #expect(try localizedString("video_gravity.fill", locale: "ja") == "引き伸ばし")
    }

    @Test func screen_target_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("screen_target.all", locale: "en") == "All Displays")
        #expect(try localizedString("screen_target.all", locale: "ja") == "すべての画面")
        #expect(try localizedString("screen_target.builtin", locale: "en") == "Built-in Display Only")
        #expect(try localizedString("screen_target.builtin", locale: "ja") == "内蔵ディスプレイのみ")
        #expect(try localizedString("screen_target.external", locale: "en") == "External Displays Only")
        #expect(try localizedString("screen_target.external", locale: "ja") == "外部モニターのみ")
    }

    @Test func menu_fixed_action_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("menu.quit", locale: "en") == "Quit")
        #expect(try localizedString("menu.quit", locale: "ja") == "終了")
        #expect(try localizedString("menu.launch_at_login", locale: "en") == "Launch at Login")
        #expect(try localizedString("menu.launch_at_login", locale: "ja") == "ログイン時に起動")
    }

    @Test func status_item_accessibility_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("status.accessibility.label", locale: "en") == "VideoWallpaper status")
        #expect(try localizedString("status.accessibility.label", locale: "ja") == "VideoWallpaper の状態")
        #expect(try localizedString("status.accessibility.value.normal", locale: "en") == "No wallpaper errors")
        #expect(try localizedString("status.accessibility.value.normal", locale: "ja") == "壁紙エラーなし")
        #expect(try localizedString("status.accessibility.value.error", locale: "en") == "Wallpaper error")
        #expect(try localizedString("status.accessibility.value.error", locale: "ja") == "壁紙エラーあり")
        #expect(try localizedString("status.tooltip.normal", locale: "en") == "VideoWallpaper is running")
        #expect(try localizedString("status.tooltip.normal", locale: "ja") == "VideoWallpaper は動作中です")
        #expect(try localizedString("status.tooltip.error", locale: "en") == "VideoWallpaper needs attention")
        #expect(try localizedString("status.tooltip.error", locale: "ja") == "VideoWallpaper に確認が必要です")
    }

    @Test func menu_wallpaper_action_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("menu.wallpaper.current", locale: "en") == "Wallpaper: %@")
        #expect(try localizedString("menu.wallpaper.current", locale: "ja") == "壁紙: %@")
        #expect(try localizedString("menu.wallpaper.clear", locale: "en") == "Clear Wallpaper")
        #expect(try localizedString("menu.wallpaper.clear", locale: "ja") == "壁紙を解除")
    }

    @Test func menu_playlist_navigation_keys_are_translated_for_both_locales() throws {
        #expect(try localizedString("menu.playlist.next", locale: "en") == "Next Video")
        #expect(try localizedString("menu.playlist.next", locale: "ja") == "次の動画")
        #expect(try localizedString("menu.playlist.previous", locale: "en") == "Previous Video")
        #expect(try localizedString("menu.playlist.previous", locale: "ja") == "前の動画")
        #expect(try localizedString("menu.playlist.current", locale: "en") == "Current: %@")
        #expect(try localizedString("menu.playlist.current", locale: "ja") == "再生中: %@")
        #expect(try localizedString("menu.playlist.clear", locale: "en") == "Clear Playlist")
        #expect(try localizedString("menu.playlist.clear", locale: "ja") == "プレイリストを消去")
    }

    @Test func playlist_editor_ui_labels_are_translated_for_both_locales() throws {
        #expect(try localizedString("playlist_editor.title", locale: "en") == "Playlist Editor")
        #expect(try localizedString("playlist_editor.title", locale: "ja") == "プレイリスト編集")
        #expect(try localizedString("playlist_editor.add_videos", locale: "en") == "Add Videos")
        #expect(try localizedString("playlist_editor.add_videos", locale: "ja") == "動画を追加")
        #expect(try localizedString("playlist_editor.delete", locale: "en") == "Delete")
        #expect(try localizedString("playlist_editor.delete", locale: "ja") == "削除")
        #expect(try localizedString("playlist_editor.empty_state", locale: "en") == "No Videos")
        #expect(try localizedString("playlist_editor.empty_state", locale: "ja") == "動画がありません")
        #expect(try localizedString("playlist_editor.start_time", locale: "en") == "Start Time (seconds)")
        #expect(try localizedString("playlist_editor.start_time", locale: "ja") == "開始時間（秒）")
        #expect(try localizedString("playlist_editor.end_time", locale: "en") == "End Time (seconds)")
        #expect(try localizedString("playlist_editor.end_time", locale: "ja") == "終了時間（秒）")
    }

    private func localizedString(_ key: String, locale: String) throws -> String {
        let bundle = Bundle(for: AppDelegate.self)
        let path = try #require(bundle.path(forResource: locale, ofType: "lproj"))
        let localizedBundle = try #require(Bundle(path: path))
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
