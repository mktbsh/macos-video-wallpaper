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

### `WallpaperWindowController` — `clearVideo()` 追加 / `load` 修正

```swift
func clearVideo() {
    playerLooper = nil
    player.pause()
    window.orderOut(nil)
}

func load(videoURL url: URL) {
    playerLooper = nil
    playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    window.orderFront(nil)   // 追加: 再選択時にウィンドウを復元
    player.play()
}
```

### `StatusMenuController` — `onVideoCleared` コールバック / メニュー項目追加

- `var onVideoCleared: (() -> Void)?` プロパティを追加
- `buildMenu()` 内で `currentVideoName != nil` のとき「壁紙を解除」を「動画を選択…」の直下に追加
- `@objc clearVideoAction()`: `clearBookmark()` → `currentVideoName = nil` → `onVideoCleared?()`

### `AppDelegate` — `onVideoCleared` ハンドラ登録

```swift
menu.onVideoCleared = { [weak self] in
    self?.windowControllers.forEach { $0.clearVideo() }
}
```

## Behavior

| 操作 | 結果 |
|------|------|
| 動画選択中に「壁紙を解除」をタップ | ウィンドウ非表示、macOS 壁紙が見える、メニュー項目が消える |
| 解除後に「動画を選択…」で再選択 | ウィンドウ復元、動画再生開始 |
| 動画未設定時 | 「壁紙を解除」は表示されない |
