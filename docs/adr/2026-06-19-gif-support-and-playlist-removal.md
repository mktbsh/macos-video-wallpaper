---
title: GIF 壁紙対応と dormant playlist サブシステムの全削除
date: 2026-06-19
status: accepted
author: Claude Opus 4.8 (claude-opus-4-8)
---

# GIF 壁紙対応と dormant playlist サブシステムの全削除

## 背景

現在の壁紙再生は ADR 2026-06-12（全ディスプレイ同一動画への移行）以降、
`WallpaperVideoStore` が保持する **グローバル動画 1 本** を全 controller に
`load(videoURL:)` するだけの経路に単純化されている。

一方で playlist サブシステム（`PlaylistStore` / `PlaybackSession` /
`RotationEngine` / `PlaylistEditorWindowController` / `PlaylistModels` /
`PlaylistPersistence`）と、それに付随する `timeRange`（トリミング再生）/
`forwardPlaybackEndTime` / `seek` 機構は **コード上残存しているが完全に到達不能**
である:

- 壁紙再生の唯一の入口 `applyGlobalVideo` は `load(videoURL:url, timeRange: nil,
  itemID: nil, token: nil)` と **timeRange を常に nil でハードコード**している
  （`AppDelegate.swift`）。
- `onPlaybackFinished = { _ in }` で playlist ローテーションも無効化済み。
- `showPlaylistEditor()` は定義されているが **呼び出し元がゼロ**。メニューに
  「Edit Playlist」項目が存在せず、UI からエディタを開く経路がない。

ADR 2026-06-12 は「playlist コードは dormant のまま温存」とスコープ外に置いた。
本 ADR はその dormant コードを削除し、同時にユーザー要望である GIF
（アニメーション GIF）の壁紙対応を追加する。

GIF は AVFoundation のデコード対象外（`AVPlayer` で再生不可）であり、別経路の
描画が必要になる。本 ADR は再生経路を「URL 1 本をループ」だけに単純化したうえで、
そこへ動画 / GIF を種別ごとの driver で載せる構造を採る。

## 決定

### 1. dormant playlist サブシステムの全削除

到達不能なため移行・互換維持は行わず、クリーンカットで削除する。

- 削除する型・ファイル: `PlaylistStore` / `PlaybackSession` / `RotationEngine` /
  `PlaylistEditorWindowController` / `PlaylistModels` / `PlaylistPersistence`、
  および対応するテスト群（`PlaylistEditorWindowControllerTests` /
  `PlaylistStoreTests` / `PlaylistStoreMutationTests` / `PlaylistPersistenceTests` /
  `PlaybackSessionTests` など）。
- `PlaybackCompletion` / `PlaybackCompletionObserver`（`NotificationPlaybackCompletionObserver`）/
  `PlaybackObservationTarget`（`AVPlayerObservationTarget`）を **型ごと削除**する
  （ループ・失敗観測を driver 責務へ移すため。決定 3 参照）。
- ローカライズ `menu.playlist.*` 文字列を `Localizable.xcstrings` から削除。
- `AppDelegate` から playlist 関連メンバ・メソッド
  （`playlistStore` / `playlistPersistence` / `playlistEditorWindowController` /
  `showPlaylistEditor` / `configure(editor:)` / `updatePlaylistItem` 他）を削除。
- 削除後の永続化は `WallpaperVideoStore` の単一 bookmark キーのみ。playlist の
  保存データ（`PlaylistPersistence` 経由）は読まない・移行しない。

### 2. 再生経路の単純化（timeRange / seek の撤去）

- `WallpaperWindowController.load` のシグネチャを `load(videoURL:)` のみに縮約し、
  `timeRange` / `itemID` / `token` 引数を削除する。
- `PlaybackContext`（itemID/timeRange/token を持つ構造体）を撤去し、controller は
  現在の URL と security-scoped access handle のみを保持する。
- `PlaylistItem.playbackTimeRange` / `startTime` / `endTime` および
  `forwardPlaybackEndTime` を全廃。
- ループは **driver の責務** とし、controller から `seek` / 再生完了観測を撤去する
  （決定 3 参照）。controller に残るのは load / play / pause / clear /
  dim / gravity / 表示制御 / 失敗転送のみ。

### 3. PlayerDriver protocol を CALayer ベース + ループ自己完結へ

動画 driver と GIF driver はレイヤー実体が異なる（`AVPlayerLayer` vs `CALayer`）
ため protocol を上位の `CALayer` に緩め、ループと失敗観測を **driver の責務** に統一する。
これにより `WallpaperWindowController` から再生完了観測・seek・pending-seek 状態が
撤去され、controller は表示制御に専念する。

新しい protocol（概形）:

```swift
@MainActor
protocol PlayerDriver: AnyObject {
    var layer: CALayer { get }
    var onPlaybackFailed: (() -> Void)? { get set }
    func load(url: URL)
    func play()
    func pause()
    func clear()
    func applyGravity(_ gravity: VideoGravity)
}

@MainActor
protocol PlayerDriverFactory {
    func makeDriver(for url: URL) -> PlayerDriver
}
```

- **動画（`AVPlayerDriver`）**: `AVQueuePlayer` + `AVPlayerLooper` でギャップレス
  ループ（`CLAUDE.md` のアーキ図に回帰）。`AVPlayerItem.status == .failed` を KVO で
  監視し `onPlaybackFailed` を発火。`layer` は `AVPlayerLayer`、`applyGravity` は
  `videoGravity` にマップ。
- **GIF（`GIFPlayerDriver`）**: `CALayer` に `CAKeyframeAnimation`
  （`repeatCount = .infinity`）で内部ループ。フレーム抽出に失敗したら
  `onPlaybackFailed` を発火。`applyGravity` は `contentsGravity` にマップ。
- `seek` / `forwardPlaybackEndTime` / `replaceCurrentItem` / completion 観測 API は
  protocol から消滅する。
- `VideoGravity` に `caGravity: CALayerContentsGravity`（fill→`.resizeAspectFill`、
  fit→`.resizeAspect`、stretch→`.resize`）を追加し、GIF driver が参照する。

### 4. メディア種別による driver 生成と layer 差し替え

- `WallpaperWindowController.load(videoURL:)` が拡張子から種別を判定し、
  `AVPlayerDriver`（mp4/mov/m4v）か `GIFPlayerDriver`（gif）を生成する。
- driver factory を「種別 → driver」を返す形へ変更する
  （例: `MediaPlayerDriverFactory.makeDriver(for url: URL) -> PlayerDriver`）。
  既存テストの注入ポイント（`driverFactory`）は維持する。
- 種別が変わる読み込みでは、古い `driver.layer` をサブレイヤーから除去し、
  新 driver の `layer` を追加し直し、gravity / dim を再適用する。
- `VideoFileType`（純粋 enum）に `gif` を許可拡張子・`UTType.gif` を追加する。
  ドラッグ&ドロップ判定（`DropDestinationView`）とファイル選択ダイアログの
  `allowedContentTypes` の両方が新しい許可形式を参照する。

### 5. GIFPlayerDriver の実装方式

- `CGImageSource`（ImageIO）で全フレームの `CGImage` と各フレーム delay
  （`kCGImagePropertyGIFUnclampedDelayTime` →無ければ `kCGImagePropertyGIFDelayTime`、
  下限クランプ）を抽出する。
- `CAKeyframeAnimation`（keyPath: `contents`）を `layer` に付与し、各フレームの
  累積時刻を `keyTimes`、`calculationMode = .discrete`、`repeatCount = .infinity`
  とする。
- `play` / `pause` は `layer` の `speed` / `timeOffset` / `beginTime` 制御で実装し、
  既存の低電力モード・オクルージョン pause / resume と同じ経路に乗せる。
- フレーム抽出 + delay 計算 + 累積 keyTimes 生成の純粋ロジックを、ImageIO/CALayer
  から切り離した値計算関数として実装し、単体テスト可能にする。

### 6. メモリは初版で制約なし（YAGNI）

GIF は全フレームを `CGImage` 展開するため、常駐壁紙では大きい GIF でメモリを
消費する。初版はダウンサンプル等の対策を入れず、小〜中規模 GIF を前提とする。
必要が生じたら後続で `CGImageSourceCreateThumbnailAtIndex` による画面解像度への
ダウンサンプルを追加する（本 ADR ではリスクとして明記、実装はしない）。

## テスト方針（TDD / Swift Testing）

- `VideoFileType`: `gif` が `isSupported` で許可され、`allowedUTTypes` に
  `UTType.gif` が含まれることを検証。
- driver 選択ロジック: 拡張子（mp4/mov/m4v/gif、大文字小文字、非対応）から
  期待する driver 種別が選ばれることを検証。
- `GIFPlayerDriver` の純粋ロジック: 既知の delay プロパティ配列から累積 keyTimes と
  total duration が正しく計算されること、delay 下限クランプが効くことを検証。
- driver の失敗通知: フレーム抽出失敗 / `AVPlayerItem` failed で `onPlaybackFailed`
  が controller 経由で `AppDelegate` のエラー表示まで伝播することを検証。
- 既存 `WallpaperWindowControllerTests` / `WallpaperWindowControllerVisibilityTests` /
  `PlaybackDriverTests` / `PlaybackFailureTests` / `WallpaperWindowTestHelpers`
  （`FakePlayerDriver` 等）を新 protocol（CALayer ベース・ループ自己完結・seek/observer
  撤去）に合わせて書き換える。
- 削除に伴い playlist 系テスト群（`PlaylistStoreTests` / `PlaylistStoreMutationTests` /
  `PlaylistPersistenceTests` / `PlaybackSessionTests` / `RotationEngineTests` /
  `PlaylistEditorWindowControllerTests`）を削除する。
- `LocalizationCatalogTests` から `menu.playlist.*` / `playlist_editor.*` の期待を削除する。
- `FakeWallpaperWindowController` の `load` を新シグネチャ（`load(videoURL:)`）に追従。
- 受け入れ基準: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'`
  がグリーン。実機で GIF をドラッグ&ドロップ / 選択して壁紙としてループ再生され、
  明るさ調整・表示方法（Cover/Contain/Fill）・低電力 pause が GIF にも効くこと。

## 影響

- playlist サブシステムと timeRange/seek 機構の削除で相当量のコード純減
  （production + テスト）。再生経路が「URL 1 本をループ」に一本化され、driver 抽象が
  CALayer ベースに整理される。
- `tasks/todo.md` の P1/P2 に残る playlist 関連タスク（production menu 接続、
  `PlaybackSession` 統合、ローテーション integration test、`PlaylistPersistence`
  分離等）は本決定により **不要化** するため、todo から削除する。
- ドメイン用語 `CONTEXT.md` を更新（playlist 用語の除去、GIF / driver 種別の追記）。
- `project.yml` のファイル増減に伴い `xcodegen generate` を実行する。

## スコープ外 / リスク

- Animated WebP / APNG は対象外（別 ADR）。本 ADR は GIF のみ。
- 大きい GIF のメモリ消費は初版で未対策（決定 6）。後続でダウンサンプル検討。
- GIF の再生速度精度は `CAKeyframeAnimation` の `keyTimes` 解像度に依存する。
  可変フレーム delay は累積 keyTimes で表現するが、極端に多フレームな GIF での
  精度・メモリは初版の対象外とする。
