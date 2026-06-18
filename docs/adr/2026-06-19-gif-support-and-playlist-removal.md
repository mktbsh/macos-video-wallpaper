---
title: GIF 壁紙対応と dormant playlist サブシステムの全削除
date: 2026-06-19
status: proposed
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
- `PlaybackCompletion` から `itemID` / `token` を除去（または型ごと整理）。
- ローカライズ `menu.playlist.*` 文字列を `Localizable.xcstrings` から削除。
- `AppDelegate` から playlist 関連メンバ・メソッド
  （`playlistStore` / `playlistPersistence` / `playlistEditorWindowController` /
  `showPlaylistEditor` / `configure(editor:)` / `updatePlaylistItem` 他）を削除。
- 削除後の永続化は `WallpaperVideoStore` の単一 bookmark キーのみ。playlist の
  保存データ（`PlaylistPersistence` 経由）は読まない・移行しない。

### 2. 再生経路の単純化（timeRange / seek の撤去）

- `WallpaperWindowController.load` のシグネチャを `load(videoURL:)` のみに縮約し、
  `timeRange` / `itemID` / `token` 引数を削除する。
- `PlaybackContext` から `timeRange` / `itemID` / `token` を削除する。
- `PlaylistItem.playbackTimeRange` / `startTime` / `endTime` および
  `forwardPlaybackEndTime` を全廃。
- 動画のループは現行の「再生終了 → completion → 先頭へ戻して再生」を維持する。
  ただし `seek(to:)` は **driver 内部のループ手段** に閉じ、controller から
  任意 time への seek を要求する API は持たない（先頭復帰のみ）。

### 3. PlayerDriver protocol を CALayer ベースへ

動画 driver と GIF driver はレイヤー実体が異なる（`AVPlayerLayer` vs `CALayer`）
ため、protocol を上位の `CALayer` に緩める。

- `var layer: AVPlayerLayer` → `var layer: CALayer`。
- `videoGravity` の直接設定をやめ、`applyGravity(_ gravity: VideoGravity)` を
  protocol メソッド化する。`AVPlayerDriver` は `AVPlayerLayer.videoGravity` に、
  `GIFPlayerDriver` は `CALayer.contentsGravity` にマップする。
- `seek(to:toleranceBefore:toleranceAfter:completion:)` /
  `forwardPlaybackEndTime` を protocol から削除。再生終了の通知 / ループは
  driver の責務に寄せる:
  - 動画: 再生終了を観測して completion を発火（既存の手動ループを driver 側で完結、
    もしくは現行どおり controller でループ）。
  - GIF: `CAKeyframeAnimation` の `repeatCount = .infinity` で内部ループし、
    completion を発火しない。

> 注: ループ責務を driver と controller のどちらに置くかは実装方針の確定事項として
> 実装計画フェーズで詰める。protocol を CALayer ベースに緩める点と、controller が
> 任意 seek を要求しない点は本 ADR で確定とする。

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
- 既存 `WallpaperWindowControllerTests` /
  `WallpaperWindowControllerVisibilityTests` を新シグネチャ（timeRange 撤去）に追従。
- 削除に伴い playlist 系テスト群を削除する。
- `LocalizationCatalogTests` から `menu.playlist.*` の期待を削除する。
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
