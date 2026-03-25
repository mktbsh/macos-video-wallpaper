# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい

---

## Feature: 動画サムネイルをシステム壁紙に設定

動画選択時に、その動画の代表フレームをシステム壁紙（静止画）として設定する。
アプリ未起動中・ロック画面でも動画の雰囲気に合った壁紙が表示される。

### 要件

- 動画選択・変更時に自動で実行する（ユーザー操作不要）
- 使用フレーム: **動画尺の 10% 位置**（フェードイン・黒フレームを自然に回避）
- 全ディスプレイに同じサムネイルを設定する
- サムネイル画像は `~/Library/Caches/VideoWallpaper/thumbnail.jpg` に保存する

### 技術メモ

- フレーム抽出: `AVAssetImageGenerator`
  ```swift
  let asset = AVAsset(url: videoURL)
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true  // 回転補正

  // 尺の 10% 位置を指定
  let duration = try await asset.load(.duration)
  let offset = CMTimeMultiplyByFloat64(duration, multiplier: 0.1)
  let (cgImage, _) = try await generator.image(at: offset)
  ```
- 画像保存: `CGImageDestination`（JPEG、quality 0.85 程度）
- システム壁紙設定: `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`
  - `NSScreen.screens` をループして全画面に適用
- キャッシュディレクトリ作成: `FileManager.default.createDirectory(at:...)`

### タスクリスト

- [ ] `ThumbnailService` を `Sources/ThumbnailService.swift` に新規作成する
- [ ] `AVAssetImageGenerator` で動画尺の 10% フレームを抽出するロジックを実装する
- [ ] 抽出した `CGImage` を JPEG として `~/Library/Caches/VideoWallpaper/thumbnail.jpg` に保存するロジックを実装する
- [ ] `NSWorkspace.shared.setDesktopImageURL` で `NSScreen.screens` 全画面に適用するロジックを実装する
- [ ] `AppDelegate.applyVideo(url:)` から `ThumbnailService.applyThumbnail(for:)` を `Task { }` で非同期呼び出しする
- [ ] `applicationDidFinishLaunching` で保存済み動画 URL がある場合も同様に適用する（再起動時の整合性）
- [ ] `ThumbnailServiceTests` を追加する（モック動画 URL での挙動確認）

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
