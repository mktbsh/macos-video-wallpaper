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

## Feature: 動画のフィット方法切り替え

外部モニターのアスペクト比の違いや縦動画に対応するため、動画の表示方法を選べるようにする。

### 要件

- 選択肢: AspectFill（デフォルト）/ AspectFit / Stretch
- 設定は UserDefaults に保存し、再起動後も維持する
- 変更はリアルタイムで全ウィンドウに反映する

### 技術メモ

- `AVPlayerLayer.videoGravity` を切り替える
  - `.resizeAspectFill` — 画面を埋める・クロップあり（現状）
  - `.resizeAspect` — 全体表示・黒帯あり（縦動画や異アスペクト比モニターで有効）
  - `.resize` — アスペクト比無視で引き伸ばし
- `UserDefaults` のキー: `"videoGravity"`（値: `"fill"` / `"fit"` / `"stretch"`）
- `WallpaperWindowController` に `applyVideoGravity(_:)` メソッドを追加
- `DimLevel` / `ScreenTarget` と同じパターンで `VideoGravity` enum を新規作成

### タスクリスト

- [ ] `VideoGravity` enum を `Sources/VideoGravity.swift` に新規作成する
  ```swift
  enum VideoGravity: String, CaseIterable {
      case fill    = "fill"
      case fit     = "fit"
      case stretch = "stretch"

      var label: String { ... }  // 塗りつぶし / 全体表示 / 引き伸ばし
      var avGravity: AVLayerVideoGravity { ... }
      static var saved: VideoGravity { ... }
      func save() { ... }
  }
  ```
- [ ] `WallpaperWindowController` に `applyVideoGravity(_:)` を追加し、init でも適用する
- [ ] `StatusMenuController` に「表示方法」サブメニューを追加する
- [ ] `AppDelegate` に `onVideoGravityChanged` コールバックを追加して全ウィンドウに伝播する

---

## Backlog（検討中）

- 動画のボリューム調整（ミュート解除オプション）
- 複数画面に異なる動画を設定する
- スライドショーモード（複数動画のローテーション）
- 時間帯連動（朝・昼・夜で動画を自動切り替え）
