# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい

---

## Feature: 対象画面の設定切り替え

メニューバーから「どの画面に壁紙を表示するか」を選べるようにする。

### 要件

- プリセット選択（すべての画面 / 内蔵ディスプレイのみ / 外部モニターのみ）
- 設定は UserDefaults に保存し、再起動後も維持する
- 画面の接続・切断時（`screensDidChange`）に設定を反映する

### 技術メモ

- 内蔵ディスプレイの判定: `CGDisplayIsBuiltin(displayID)` を使う
  ```swift
  // NSScreen → CGDirectDisplayID の取り換え方
  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
  let isBuiltin = CGDisplayIsBuiltin(displayID)
  ```
- `UserDefaults` のキー例: `"screenTarget"` (値: `"all"` / `"builtin"` / `"external"`)
- `WallpaperWindowController` の生成ループにフィルタを追加するだけでよい

### タスクリスト

- [ ] `ScreenTarget` enum を `VideoFileValidator.swift` か新ファイルに定義する

  ```swift
  enum ScreenTarget: String, CaseIterable {
      case all      = "all"
      case builtIn  = "builtin"
      case external = "external"

      var label: String {
          switch self {
          case .all:      return "すべての画面"
          case .builtIn:  return "内蔵ディスプレイのみ"
          case .external: return "外部モニターのみ"
          }
      }
  }
  ```

- [ ] `AppDelegate.setupWallpaperWindows()` にフィルタロジックを追加する
  ```swift
  let target = ScreenTarget(rawValue: UserDefaults.standard.string(forKey: "screenTarget") ?? "") ?? .all
  let screens = NSScreen.screens.filter { screen in
      guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return true }
      switch target {
      case .all:      return true
      case .builtIn:  return CGDisplayIsBuiltin(id)
      case .external: return !CGDisplayIsBuiltin(id)
      }
  }
  ```
- [ ] `StatusMenuController` の `buildMenu()` に「対象画面」サブメニューを追加する
  - `NSMenuItem` + `NSMenu` のサブメニュー構造
  - 選択中のプリセットに `.checkmark` state を付ける
  - 選択時に `UserDefaults` を更新し `onScreenTargetChanged` コールバックを呼ぶ
- [ ] `AppDelegate` に `onScreenTargetChanged` ハンドラを追加して `setupWallpaperWindows()` を再実行する
- [ ] `VideoFileValidatorTests` と同様のパターンで `ScreenTargetTests` を追加する（外部モニターなし環境でのフォールバック動作など）

---

## Feature: 現在再生中の動画をメニューバーで確認

メニューを開いたとき、再生中の動画ファイル名を確認できるようにする。

### 要件

- メニューの先頭に「現在の壁紙: ファイル名.mp4」を表示する（選択不可アイテム）
- 動画未設定時は「壁紙: 未設定」と表示する
- 動画を変更したらメニューの表示も更新される

### 技術メモ

- `StatusMenuController` に `currentVideoName: String?` プロパティを持たせる
- `buildMenu()` 呼び出し前に更新して再構築する
- ファイル名が長い場合は `lastPathComponent` だけ表示すれば十分

### タスクリスト

- [ ] `StatusMenuController` に `currentVideoName: String?` プロパティを追加する
- [ ] `buildMenu()` の先頭にファイル名表示アイテムを追加する
  ```swift
  let infoItem = NSMenuItem()
  infoItem.title = currentVideoName.map { "壁紙: \($0)" } ?? "壁紙: 未設定"
  infoItem.isEnabled = false
  menu.addItem(infoItem)
  menu.addItem(.separator())
  ```
- [ ] `onVideoURLChanged` ハンドラ内で `currentVideoName` を更新し `buildMenu()` を呼び直す
- [ ] `AppDelegate.applicationDidFinishLaunching` で初期値（保存済みパスのファイル名）を渡す

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
  ```swift
  import AVFoundation
  import AppKit
  import CoreGraphics

  enum ThumbnailService {
      static func applyThumbnail(for videoURL: URL) async throws {
          // 1. フレーム抽出
          // 2. キャッシュ保存
          // 3. 全画面にシステム壁紙として設定
      }
  }
  ```
- [ ] `AVAssetImageGenerator` で動画尺の 10% フレームを抽出するロジックを実装する
- [ ] 抽出した `CGImage` を JPEG として `~/Library/Caches/VideoWallpaper/thumbnail.jpg` に保存するロジックを実装する
- [ ] `NSWorkspace.shared.setDesktopImageURL` で `NSScreen.screens` 全画面に適用するロジックを実装する
- [ ] `AppDelegate.applyVideo(url:)` から `ThumbnailService.applyThumbnail(for:)` を `Task { }` で非同期呼び出しする
- [ ] `applicationDidFinishLaunching` で保存済み動画 URL がある場合も同様に適用する（再起動時の整合性）
- [ ] `ThumbnailServiceTests` を追加する（モック動画 URL での挙動確認）

---

## Fix: セキュリティスコープブックマーク

現在は動画ファイルのパス文字列を UserDefaults に保存しているが、ファイルの移動・リネーム後に
再起動すると読み込めなくなる。`URL.bookmarkData()` に切り替えてファイル追跡を堅牢にする。

### 技術メモ

- 保存: `url.bookmarkData(options: .withSecurityScope)` → `UserDefaults` に `Data` で保存
- 復元: `URL(resolvingBookmarkData:options:.withSecurityScope)` → `url.startAccessingSecurityScopedResource()`
- 現在の `"videoFilePath"` キー（String）を `"videoBookmark"` キー（Data）に移行する
- 旧キーとの後方互換: 旧キーが残っていれば一度だけブックマークに変換して保存し直す

### タスクリスト

- [ ] `VideoFileValidator.resolveVideoURL(fromPath:)` を `resolveVideoURL(from:)` に変更し、引数を `Data?`（ブックマーク）に変える
- [ ] `AppDelegate` / `WallpaperWindowController` の `UserDefaults` 読み書き箇所をブックマーク方式に置き換える
- [ ] 旧 `"videoFilePath"` キーからの移行ロジックを `applicationDidFinishLaunching` に追加する
- [ ] `VideoFileValidatorTests` を更新する

---

## Feature: バッテリー節電モード

バッテリー駆動中は動画再生を一時停止し、AC 接続時に自動再開するオプション。

### 技術メモ

- 電源状態の変化: `NSWorkspace.powerSourceDidChangeNotification`
- 現在の電源判定:
  ```swift
  import IOKit.ps
  let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
  let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
  let isOnBattery = (type == kIOPMBatteryPowerKey)
  ```
- 設定は UserDefaults に保存（`"pauseOnBattery"` キー、デフォルト `false`）
- メニューバーにトグル項目を追加する

### タスクリスト

- [ ] `AppDelegate` に `pauseOnBattery` 設定値の読み書きと `powerSourceDidChange` オブザーバーを追加する
- [ ] 電源状態に応じて `windowControllers` の `resumePlayback()` / `player.pause()` を切り替えるロジックを実装する
- [ ] `StatusMenuController.buildMenu()` に「バッテリー時は一時停止」トグル項目を追加する

---

## Feature: フルスクリーンアプリ時の自動一時停止

別アプリがフルスクリーンになると壁紙ウィンドウは見えなくなるため、動画デコードを止めて CPU/GPU 負荷を下げる。

### 技術メモ

- `NSWindow` の occlusion state を監視する:
  ```swift
  NotificationCenter.default.addObserver(
      forName: NSWindow.didChangeOcclusionStateNotification,
      object: window,
      queue: .main
  ) { [weak self] _ in
      if window.occlusionState.contains(.visible) {
          self?.player.play()
      } else {
          self?.player.pause()
      }
  }
  ```
- `WallpaperWindowController` 内で完結する変更（AppDelegate への影響なし）

### タスクリスト

- [ ] `WallpaperWindowController.init` に `NSWindow.didChangeOcclusionStateNotification` オブザーバーを追加する
- [ ] occlusion state に応じて `player.play()` / `player.pause()` を切り替える
- [ ] `resumePlayback()` が occlusion 状態を考慮するよう修正する（不可視のまま再開しないようにする）

---

## Feature: 動画の明るさ（オーバーレイ）調整

動画が明るすぎてデスクトップアイコンが見にくい場合に、半透明の暗転レイヤーで調整する。

### 技術メモ

- `AVPlayerLayer` の上に `CALayer` を重ねて `backgroundColor` を `black.withAlphaComponent(opacity)` に設定する
- 設定値: `"wallpaperDimLevel"` キー（Float, 0.0〜0.7、デフォルト 0.0）
- メニューバーに段階選択（なし / 少し暗く / 暗く）で提供するのが実装コスト最小

### タスクリスト

- [ ] `WallpaperWindowController` に `dimLayer: CALayer` を追加し、`playerLayer` の上に重ねる
- [ ] `dimLevel` プロパティを追加して `dimLayer.backgroundColor` を更新するメソッドを実装する
- [ ] `StatusMenuController.buildMenu()` に「明るさ調整」サブメニュー（なし / 少し暗く / 暗く）を追加する
- [ ] 選択値を UserDefaults に保存・復元し、起動時に各ウィンドウに適用する

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
- 壁紙のフィット方法切り替え（AspectFill / AspectFit / Stretch）
- 複数画面に異なる動画を設定する
- スライドショーモード（複数動画のローテーション）
- 時間帯連動（朝・昼・夜で動画を自動切り替え）
