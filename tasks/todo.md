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

## Feature: ループ範囲の指定

動画の一部区間だけをループ再生する（イントロ・アウトロのカット）。

### 技術メモ

- `AVPlayerLooper(player:templateItem:timeRange:)` でループ範囲を指定できる
  ```swift
  let range = CMTimeRange(start: startTime, end: endTime)
  playerLooper = AVPlayerLooper(player: player, templateItem: item, timeRange: range)
  ```
- 設定 UI はシンプルに「開始 / 終了を秒単位で入力」で十分
- 設定は動画 URL に紐づけて保存する（UserDefaults のキーにファイル名を含める等）

### タスクリスト

- [ ] `WallpaperWindowController.load(videoURL:)` に `timeRange: CMTimeRange?` 引数を追加する
- [ ] `StatusMenuController` に「ループ範囲を設定…」メニュー項目と入力シートを追加する
- [ ] 設定値を `"loopRange_<filename>"` 形式のキーで UserDefaults に保存・復元する

---

## Backlog（検討中）

- 動画のボリューム調整（ミュート解除オプション）
- 複数画面に異なる動画を設定する
- スライドショーモード（複数動画のローテーション）
- 時間帯連動（朝・昼・夜で動画を自動切り替え）
