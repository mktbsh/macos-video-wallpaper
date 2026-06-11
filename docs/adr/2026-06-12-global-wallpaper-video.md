---
title: 全ディスプレイ同一動画への移行と per-display 構成の廃止
date: 2026-06-12
status: accepted
author: Claude Opus 4.8 (claude-opus-4-8)
---

# 全ディスプレイ同一動画への移行と per-display 構成の廃止

## 背景

内蔵 + 外部1枚の構成で「外部ディスプレイに壁紙が出ない」事象が報告された。
ランタイムログで切り分けた結果、内蔵/外部はそれぞれ一意な `DisplayIdentifier`
（`CGDisplayVendorNumber`/`ModelNumber`/`SerialNumber` 由来）を持ち、controller も
2 つ生成されていた。一方で `tasks/todo.md` P1 には「同型ディスプレイ / serial 0 で
`DisplayIdentifier` が衝突し片方が表示されない」既知の identity 課題があった。

これを受けてユーザーが「per-display で動画を分離せず、全ディスプレイに同一動画を
適用する」方針を選択（画面ごとの有効/無効トグルも廃止）。

## 決定

1. **壁紙動画は 1 本のグローバル動画**とし、接続中の全ディスプレイに同一適用する。
   per-display の動画割り当て・有効/無効トグルは UI・永続化から廃止する。
2. **`WallpaperVideoStore`（`WallpaperVideoStoring` seam）** を導入。単一キー
   `wallpaperVideoBookmark` で 1 本の bookmark を保持。`resolveVideo()` は
   `ResolvedVideo`(noVideo / resolved / resolveFailed) を返す。
3. **完全クリーンカット**: 旧 per-display キー（`videoBookmark_display_*` /
   `displayEnabled_display_*`）も legacy 単一キー（`videoBookmark` / `videoFilePath`）も
   移行しない。新規ユーザー同様に noVideo から開始する。
4. **controller roster のキーを `CGDirectDisplayID`** に変更する。これは実行時に
   各アクティブディスプレイで一意であり、同型 / serial 0 の衝突を構造的に排除する
   （= P1 の identity 課題を解消）。`DisplayIdentifier` struct は廃止し、
   `NSScreen.displayID` 拡張に置き換える。
5. **適用範囲の分離**: 画面再構成（起動 / screen 変更）では**新規 controller のみ**に
   load する（生存 controller は同一グローバル動画を保持済みで触らない＝churn を避ける
   既存の不変条件を維持）。動画の**変更時**は**全 controller** に適用する。
6. **エラーはグローバル化**。`WallpaperError` から `DisplayIdentifier` 関連値を除去し、
   AppDelegate は単一の `currentError` を保持。メニューは固定のグローバル壁紙項目
   （現在動画 / エラー / Select Video / Clear）に簡素化する。
7. window controller の callback も非 per-display 化（`onVideoDropped: (URL)->Void`、
   `onPlaybackFailed: ()->Void`）。

## 影響

- 内蔵/外部の identity 衝突に起因する「片方が表示されない」事象が構造的に解消。
- per-display 関連コード（`DisplayWallpaperStore` / `DisplayIdentifier` /
  `DisplayMenuState` とテスト）を削除し、約 1000 行の純減。
- ドメイン用語は `CONTEXT.md` を更新（DisplayWallpaperStore → WallpaperVideoStore）。

## 同時に修正した実機バグ（実機検証で発見）

「外部ディスプレイに出ない」事象は、グローバル化とは独立した 2 つの実機バグの複合だった。
本ブランチ（`fix/external-display-wallpaper`）で両方を修正し、内蔵+外部の実機で両画面に
同一動画が表示されることを確認済み。

1. **security-scoped bookmark 生成失敗**: `bookmarkData(.withSecurityScope)` が
   `NSFileReadUnknownError(256)` で失敗し、動画が保存できなかった。当初 ad-hoc 署名を
   疑ったが、開発証明書で署名しても再現。真因は entitlement が `user-selected.read-only`
   のみのため `.withSecurityScope` 単体が read-write スコープ取得で open に失敗していたこと。
   `[.withSecurityScope, .securityScopeAllowOnlyReadAccess]` に変更して解消（`SecurityScopedBookmark.data`）。
2. **外部ウィンドウが画面外に配置**: `NSWindow(... screen:)` を渡すと contentRect が
   スクリーン相対座標になり、グローバル origin が二重適用されて外部ウィンドウが
   `window.screen == nil`（画面外）になっていた。`screen:` を省略しグローバル座標で
   配置するよう修正（`WallpaperWindowController` convenience init）。

詳細は `tasks/knowledge.md` を参照。

## スコープ外 / 既知の別課題

- RotationEngine token の controller interface からの除去（アーキテクチャレビュー
  candidate 4）/ PlaybackSession 統合（candidate 2）は別タスク。playlist コードは
  dormant のまま温存。
