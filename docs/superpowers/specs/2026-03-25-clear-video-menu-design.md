# Design: 壁紙解除メニュー

## Overview

動画が選択されている状態のとき、メニューバーに「壁紙を解除」項目を追加する。
実行するとウィンドウを非表示にし、macOS 本来の壁紙を見せる。

## Changes

### `VideoFileValidator` — `clearBookmark()` 追加

```swift
static func clearBookmark() {
    UserDefaults.standard.removeObject(forKey: "videoBookmark")
}
```

セキュリティスコープリソースの停止は呼び出し元（`WallpaperWindowController.clearVideo()`）が責任を持つ。

---

### `WallpaperWindowController` — `clearVideo()` / `load()` / `init` 修正、`onVideoDropped` 追加

**`currentVideoURL` を追跡してセキュリティスコープを明示的に解放する:**

```swift
private var currentVideoURL: URL?

func clearVideo() {
    playerLooper = nil
    player.pause()
    currentVideoURL?.stopAccessingSecurityScopedResource()
    currentVideoURL = nil
    window.orderOut(nil)
}

func load(videoURL url: URL) {
    playerLooper = nil
    currentVideoURL = url
    playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    player.play()
    // orderFront は呼ばない。AppDelegate が applyBatteryPolicy() 経由で制御する
}
```

**`init` — URL がない場合はウィンドウを非表示にする:**

```swift
// 末尾の orderFront を条件付きに変更
if url != nil {
    window.orderFront(nil)
}
```

**ドラッグ&ドロップをメニューに反映するコールバックを追加:**

```swift
var onVideoDropped: ((URL) -> Void)?

// DropDestinationView.onVideoDropped の末尾
self?.onVideoDropped?(url)
```

**`clearVideo()` 後の `resumePlayback()` について:**
`clearVideo()` は `playerLooper = nil` する。`resumePlayback()` は `guard playerLooper != nil` で即リターンするため、`powerSourceDidChange` や `systemDidWake` イベントが発火しても cleared 状態のウィンドウが再表示されることはない。

---

### `AppDelegate` — `applyVideo()` 修正 / `onVideoCleared` / `onVideoDropped` ハンドラ登録

```swift
menu.onVideoCleared = { [weak self] in
    self?.windowControllers.forEach { $0.clearVideo() }
}

// 各 WallpaperWindowController 生成後
controller.onVideoDropped = { [weak self] url in
    self?.menu.currentVideoName = url.lastPathComponent
    self?.applyBatteryPolicy()  // 省電力一時停止中はドロップ後も再生しない
}
```

**`applyVideo()` に `applyBatteryPolicy()` を追加して省電力状態を維持:**

```swift
private func applyVideo(url: URL) {
    windowControllers.forEach { $0.load(videoURL: url) }
    applyBatteryPolicy()  // 省電力一時停止中は orderFront しない
}
```

---

### `StatusMenuController` — `onVideoCleared` コールバック / メニュー項目追加

- `var onVideoCleared: (() -> Void)?` プロパティを追加
- `buildMenu()` 内で `currentVideoName != nil` のとき「壁紙を解除」を「動画を選択…」の直下に追加
- アクションの実行順: `clearBookmark()` → `onVideoCleared?()` → `currentVideoName = nil`
  （`currentVideoName = nil` が `didSet` で `buildMenu()` をトリガーするため最後に置く）

---

## Behavior

| 操作 | 結果 |
|------|------|
| 動画選択中に「壁紙を解除」をタップ | ウィンドウ非表示、macOS 壁紙が見える、メニュー項目が消える |
| 解除後に「動画を選択…」で再選択 | `applyBatteryPolicy()` 経由でウィンドウ復元、動画再生開始（省電力中は再生しない） |
| 動画未設定時 | 「壁紙を解除」は表示されない |
| 解除後にアプリを再起動 | `resolveBookmarkedURL()` が nil を返す → ウィンドウは生成されるが非表示 |
| 解除後に画面追加イベント | `screensDidChange()` → `setupWallpaperWindows()` → `savedURL` が nil → ウィンドウは非表示 |
| 動画ドラッグ&ドロップ | `onVideoDropped` コールバック経由で `menu.currentVideoName` を更新 → 「壁紙を解除」が表示される |
| 省電力一時停止中に再選択 | `applyBatteryPolicy()` が `pausePlayback()` を再呼び出し → ウィンドウは非表示のまま |

## Known Limitations

- `stopAccessingSecurityScopedResource()` は `resolveBookmarkedURL()` で開始された分のみ解放する。複数画面でそれぞれ同じ URL が使われる場合、最初の `startAccessing` 1 回に対して `clearVideo()` が複数回 `stop` を呼ぶが、これは既存コードの設計上の制約であり本 PR のスコープ外とする。
