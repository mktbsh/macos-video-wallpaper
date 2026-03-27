# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい

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
- [x] 画面構成変更時の壁紙ウィンドウ更新を差分適用にする
- [x] `StatusMenuController` の menu rebuild をやめ、固定 `NSMenuItem` の差分更新にする

---

## Backlog（検討中）

- 動画のボリューム調整（ミュート解除オプション）
- 複数画面に異なる動画を設定する
- 時間帯連動（朝・昼・夜で動画を自動切り替え）
