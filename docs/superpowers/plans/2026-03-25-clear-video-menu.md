# 壁紙解除メニュー Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 動画が選択されているときメニューバーに「壁紙を解除」項目を表示し、タップするとウィンドウを非表示にして macOS 本来の壁紙を見せる。

**Architecture:** `VideoFileValidator` でブックマーク削除、`WallpaperWindowController` でウィンドウ非表示とセキュリティスコープ解放、`StatusMenuController` にメニュー項目と `onVideoCleared` コールバックを追加し、`AppDelegate` で全体を配線する。

**Tech Stack:** Swift, Cocoa, AVFoundation, Swift Testing

---

## File Map

| ファイル | 変更内容 |
|---------|---------|
| `Sources/VideoFileValidator.swift` | `clearBookmark()` 追加 |
| `Sources/WallpaperWindowController.swift` | `clearVideo()` 追加、`load()` 修正、`init` 修正、`onVideoDropped` コールバック追加 |
| `Sources/AppDelegate.swift` | `applyVideo()` 修正、`onVideoCleared` / `onVideoDropped` ハンドラ登録 |
| `Sources/StatusMenuController.swift` | `onVideoCleared` コールバック追加、`buildMenu()` に「壁紙を解除」追加、`@objc clearVideoAction()` 追加 |
| `Tests/VideoWallpaperTests/VideoFileValidatorTests.swift` | `clearBookmark()` のテスト追加 |

---

## Task 1: `VideoFileValidator.clearBookmark()` をテスト駆動で追加

**Files:**
- Modify: `Tests/VideoWallpaperTests/VideoFileValidatorTests.swift`
- Modify: `Sources/VideoFileValidator.swift`

- [ ] **Step 1: 失敗するテストを書く**

`VideoFileValidatorTests` の末尾 — **`@Suite(.serialized) struct VideoFileValidatorTests { }` の閉じ括弧 `}` の直前**（struct の外ではなく内側）に追加。
`@Suite(.serialized)` が必要な理由: `UserDefaults.standard` を読み書きするため、並列実行すると競合する:

```swift
// MARK: - clearBookmark()

@Test func clearBookmark_removes_stored_bookmark() {
    UserDefaults.standard.set(Data([0x01]), forKey: "videoBookmark")
    defer { UserDefaults.standard.removeObject(forKey: "videoBookmark") }

    VideoFileValidator.clearBookmark()

    #expect(UserDefaults.standard.data(forKey: "videoBookmark") == nil)
}

@Test func clearBookmark_is_noop_when_no_bookmark() {
    UserDefaults.standard.removeObject(forKey: "videoBookmark")
    // Should not crash
    VideoFileValidator.clearBookmark()
    #expect(UserDefaults.standard.data(forKey: "videoBookmark") == nil)
}
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "(error:|FAILED|passed|failed)"
```

期待: `clearBookmark` が存在しないためコンパイルエラー

- [ ] **Step 3: `VideoFileValidator` に `clearBookmark()` を実装**

`Sources/VideoFileValidator.swift` の `saveBookmark(for:)` の直下に追加:

```swift
/// Removes the stored security-scoped bookmark from UserDefaults.
/// Callers are responsible for stopping security-scoped access before calling this.
static func clearBookmark() {
    UserDefaults.standard.removeObject(forKey: "videoBookmark")
}
```

- [ ] **Step 4: テストを実行してグリーンを確認**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "(error:|FAILED|passed|failed)"
```

期待: 全テスト PASSED

- [ ] **Step 5: コミット**

```bash
git add Sources/VideoFileValidator.swift Tests/VideoWallpaperTests/VideoFileValidatorTests.swift
git commit -m "feat: VideoFileValidator に clearBookmark() を追加"
```

---

## Task 2: `WallpaperWindowController` を修正

`WallpaperWindowController` は AVFoundation と NSWindow を直接操作するため UI テストは省略し、コードレビューで品質担保する。

**Files:**
- Modify: `Sources/WallpaperWindowController.swift`

- [ ] **Step 1: `currentVideoURL` プロパティを追加**

`private var playerLooper: AVPlayerLooper?` の直下に追加:

```swift
private var currentVideoURL: URL?
```

- [ ] **Step 2: `load(videoURL:)` を修正** — `currentVideoURL` を追跡し `orderFront` を削除

既存の `load(videoURL:)` を以下に置き換える:

```swift
func load(videoURL url: URL) {
    playerLooper = nil
    currentVideoURL = url
    playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    player.play()
    // orderFront は AppDelegate の applyBatteryPolicy() が制御する
}
```

- [ ] **Step 3: `clearVideo()` を追加**

`load(videoURL:)` の直下に追加:

```swift
/// ビデオ再生を停止し、ウィンドウを非表示にする。
/// セキュリティスコープアクセスを解放する。
func clearVideo() {
    playerLooper = nil
    player.pause()
    currentVideoURL?.stopAccessingSecurityScopedResource()
    currentVideoURL = nil
    window.orderOut(nil)
}
```

- [ ] **Step 4: `init` の `window.orderFront(nil)` を条件付きに変更**

`Sources/WallpaperWindowController.swift` の末尾近くにある `window.orderFront(nil)` の行を:

```swift
// Before
window.orderFront(nil)
```

↓

```swift
// After: URL がある場合のみウィンドウを表示する
if url != nil {
    window.orderFront(nil)
}
```

- [ ] **Step 5: `onVideoDropped` コールバックを追加してドラッグ&ドロップ時にも伝播させる**

クラス先頭の `private let window: NSWindow` などプロパティ群の直後に追加:

```swift
var onVideoDropped: ((URL) -> Void)?
```

`DropDestinationView.onVideoDropped` クロージャ内（`self?.load(videoURL: url)` の直後）に追加:

```swift
self?.onVideoDropped?(url)
```

- [ ] **Step 6: ビルドが通ることを確認**

```bash
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet clean build 2>&1 | grep -E "(error:|warning:|BUILD)"
```

期待: `BUILD SUCCEEDED`

- [ ] **Step 7: コミット**

```bash
git add Sources/WallpaperWindowController.swift
git commit -m "feat: WallpaperWindowController に clearVideo() / onVideoDropped を追加"
```

---

## Task 3: `AppDelegate` を修正

**Files:**
- Modify: `Sources/AppDelegate.swift`

- [ ] **Step 1: `applyVideo()` に `applyBatteryPolicy()` を追加**

既存の `applyVideo(url:)` を以下に置き換える:

```swift
private func applyVideo(url: URL) {
    windowControllers.forEach { $0.load(videoURL: url) }
    applyBatteryPolicy()  // 省電力一時停止中は orderFront しない
}
```

- [ ] **Step 2: `onVideoCleared` コールバックを登録**

`applicationDidFinishLaunching` 内の `menu.onVideoGravityChanged = ...` の直後に追加:

```swift
menu.onVideoCleared = { [weak self] in
    self?.windowControllers.forEach { $0.clearVideo() }
}
```

- [ ] **Step 3: `setupWallpaperWindows()` で `onVideoDropped` を配線**

`setupWallpaperWindows()` 内の `windowControllers.append(...)` を以下に変更:

```swift
let controller = WallpaperWindowController(screen: screen, videoURL: savedURL)
controller.onVideoDropped = { [weak self] url in
    // applyVideo() で全コントローラに新しい動画を適用する（マルチモニタ対応）。
    // ドロップされたコントローラ自身は DropDestinationView 内で load() 済みだが
    // 再度 load() しても問題ない（冪等）。
    // applyVideo() 内の applyBatteryPolicy() が省電力ポリシーも再適用する。
    self?.statusMenuController?.currentVideoName = url.lastPathComponent
    self?.applyVideo(url: url)
}
windowControllers.append(controller)
```

※ `statusMenuController` と `applyVideo` はどちらも `AppDelegate` のメンバーのため問題なし。
※ この `onVideoDropped` コールバックが設定されるのは `setupWallpaperWindows()` 実行後なので、
　 コールバックが nil の状態でドロップが行われることはない（初回起動時も `applicationDidFinishLaunching` → `setupWallpaperWindows()` の順に実行される）。

- [ ] **Step 4: ビルドが通ることを確認**

```bash
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet clean build 2>&1 | grep -E "(error:|warning:|BUILD)"
```

期待: `BUILD SUCCEEDED`

- [ ] **Step 5: コミット**

```bash
git add Sources/AppDelegate.swift
git commit -m "feat: AppDelegate に onVideoCleared / onVideoDropped ハンドラを追加"
```

---

## Task 4: `StatusMenuController` に「壁紙を解除」メニュー項目を追加

**Files:**
- Modify: `Sources/StatusMenuController.swift`

- [ ] **Step 1: `onVideoCleared` プロパティを追加**

既存のコールバックプロパティ群（`onVideoGravityChanged` の直後）に追加:

```swift
var onVideoCleared: (() -> Void)?
```

- [ ] **Step 2: `buildMenu()` に「壁紙を解除」項目を追加**

`buildMenu()` 内の `selectItem.target = self` / `menu.addItem(selectItem)` の直後（`let screenMenu = NSMenu()` の前）に追加:

```swift
if currentVideoName != nil {
    let clearItem = NSMenuItem(
        title: "壁紙を解除",
        action: #selector(clearVideoAction),
        keyEquivalent: ""
    )
    clearItem.target = self
    menu.addItem(clearItem)
}
```

- [ ] **Step 3: `clearVideoAction()` を実装**

`selectVideo()` の直下に追加:

```swift
@objc private func clearVideoAction() {
    // clearBookmark() は UserDefaults のエントリを削除するだけ。
    // セキュリティスコープアクセストークンは生きたままなので、
    // 次に onVideoCleared?() で clearVideo() が呼ばれるまで安全にアクセスできる。
    VideoFileValidator.clearBookmark()
    onVideoCleared?()
    currentVideoName = nil  // didSet で buildMenu() をトリガー
}
```

- [ ] **Step 4: ビルドが通ることを確認**

```bash
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet clean build 2>&1 | grep -E "(error:|warning:|BUILD)"
```

期待: `BUILD SUCCEEDED`

- [ ] **Step 5: 全テストがグリーンであることを確認**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "(error:|FAILED|passed|failed)"
```

期待: 全テスト PASSED

- [ ] **Step 6: コミット**

```bash
git add Sources/StatusMenuController.swift
git commit -m "feat: StatusMenuController に壁紙を解除メニュー項目を追加"
```

---

## Task 5: 動作確認

- [ ] **Step 1: アプリをビルドしてインストール・起動**

```bash
make run
```

- [ ] **Step 2: 動画未設定状態でメニューを開く**

「壁紙を解除」が表示されないことを確認。

- [ ] **Step 3: 動画を選択してメニューを開く**

「壁紙を解除」が「動画を選択…」の直下に表示されることを確認。

- [ ] **Step 4: 「壁紙を解除」をタップ**

- ウィンドウが非表示になり macOS 壁紙が見えること
- メニューの「壁紙: ファイル名」が「壁紙: 未設定」に変わること
- 「壁紙を解除」メニュー項目が消えること

- [ ] **Step 5: 「動画を選択…」で再選択**

動画壁紙ウィンドウが復元されること。

- [ ] **Step 6: アプリを再起動**

解除後に再起動した場合、ウィンドウが表示されないこと（黒ウィンドウが残らないこと）。
