# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい

---

## Feature: App Store リリース準備 (#32)

- [x] `project.yml` 起点で `com.apple.security.app-sandbox` / `com.apple.security.files.user-selected.read-only` / `com.apple.security.files.bookmarks.app-scope` を設定する
- [x] Hardened Runtime を有効化する
- [x] Release build とフルテストで Step 1 の動作検証を完了する
- [ ] Step 2 は issue [#39](https://github.com/mktbsh/macos-video-wallpaper/issues/39) で進める
- [ ] Step 3 は issue [#40](https://github.com/mktbsh/macos-video-wallpaper/issues/40) で進める

---

## Maintenance: PR #37 CI build fix

- [x] `WallpaperWindowController` の `PlaybackContext` helper を Swift 6 access control に合わせて `private` 明示にする
- [x] `AppDelegate` の未使用ローカル変数 warning を除去する
- [x] 今回の CI 失敗パターンを `tasks/knowledge.md` に記録する

---

## Maintenance: プレイリスト永続化の負荷削減

- [x] playlist metadata と bookmark payload を分離し、current item 変更や editor 更新で bookmark を再生成しないようにする
- [x] 旧 `playlistState` 形式から新形式へ移行して既存データを維持する

---

## Maintenance: PR #20 branch fix

- [x] Lefthook の SwiftPM 用 `Package.swift` を追加する
- [x] README 英日へ `swift package --disable-sandbox lefthook install` を追記する
- [x] SwiftLint も SwiftPM plugin 経由で pre-commit から実行できるようにする
- [x] nested SwiftPM を避け、hook から SwiftLint artifact を直接実行する

---

## Feature: UI の多言語対応 (#11)

- [x] `project.yml` / `Info.plist` にローカライズ設定（`en`, `ja`）を追加する
- [x] `Sources/Localizable.xcstrings` を追加し、メニュー・アラート・enum ラベルを移行する
- [x] `StatusMenuController` / `WallpaperWindowController` の UI 文字列を `String(localized:)` ベースへ置き換える
- [x] 既存の文字列依存テストを locale-aware に修正し、ローカライズ smoke test を追加する

---

## Feature: プレイリストベースの再生範囲

複数動画をプレイリストで管理し、各動画ごとに「全尺」または「開始 / 終了秒の範囲」を再生区間として扱う。

### タスクリスト

- [x] `WallpaperWindowController.load(videoURL:timeRange:)` で範囲再生を扱えるようにする
- [x] `PlaylistItem` / `PlaylistStore` を追加し、表示名と再生範囲を playlist entry に持たせる
- [x] `PlaylistEditorWindowController` で開始 / 終了秒と「動画全体を使う」を編集できるようにする
- [x] `StatusMenuController` に `Add Videos…` / `Edit Playlist…` / `Next` / `Previous` / `Clear` を追加する
- [x] プレイリストを永続化して再起動後も復元する
- [x] 再生完了をトリガーに次の動画へ自動ローテーションする

---

## Maintenance: パフォーマンス改善

- [x] bookmark 解決を pure にし、security-scoped access の開始 / 終了を再生側に集約する
- [x] drag & drop 時の重複 `load()` を解消し、同一 URL + timeRange の再生を no-op にする
- [x] 同一 media の token 切り替えでは `AVPlayerItem` / security-scoped access を再利用しつつ seek で再始動する
- [x] 画面構成変更時の壁紙ウィンドウ更新を差分適用にする
- [x] `StatusMenuController` の menu rebuild をやめ、固定 `NSMenuItem` の差分更新にする
- [x] playlist editor の start / end 編集を 1 回の time-range commit にまとめ、current item の再生更新 churn を減らす
- [x] `WallpaperWindowController` の pause / resume / clear を冪等化し、重複 `orderFront` / `orderOut` と不要な `play` / `pause` を抑制する

---

## Maintenance: `WallpaperWindowController` の test seam

- [x] `PlayerDriver` / `PlaybackCompletionObserver` / `SecurityScopedAccessController` を追加する
- [x] fake dependency ベースで `WallpaperWindowController` の media lifecycle edge case をテストする

---

## Backlog（検討中）

- 動画のボリューム調整（ミュート解除オプション）
- 複数画面に異なる動画を設定する
- 時間帯連動（朝・昼・夜で動画を自動切り替え）
