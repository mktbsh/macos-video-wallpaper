---
title: ドメイン用語集
updated: 2026-06-10
---

# CONTEXT — ドメイン用語集

アーキテクチャレビュー・設計会話で使う、このプロジェクト固有の用語。
コード・テスト・ドキュメントではこの語彙を使い、同義語への言い換えをしないこと。

## WallpaperVideoStore（壁紙動画ストア）

全ディスプレイ共通の **1 本のグローバル壁紙動画** を永続化するストア。
画面ごとの分離は行わない（per-display 構成は ADR 2026-06-12 で廃止）。
security-scoped bookmark の生成・解決・stale 再保存・`/private/` パス正規化は implementation 内の関心事であり、caller には見せない。

- protocol: `WallpaperVideoStoring`（seam。`resolveVideo()` / `saveVideo(_:)` / `clearVideo()`）
- production adapter: `WallpaperVideoStore`（UserDefaults キー `wallpaperVideoBookmark` + security-scoped bookmark）
- test adapter: `InMemoryWallpaperVideoStore`

## 壁紙ウィンドウ roster と displayID

接続中の各ディスプレイに 1 つ `WallpaperWindowController` を生成し、`CGDirectDisplayID`（実行時に一意）をキーに管理する。
全 controller に同一のグローバル動画を適用する。`NSScreen.displayID` で取得する。

## ResolvedVideo（動画解決結果）

台帳に問い合わせた結果の 3 状態。「未登録」と「登録はあるが解決失敗（ファイル消失等）」を caller が 1 回の呼び出しで区別できる。

- `noVideo` — その画面に動画が登録されていない
- `resolved(URL)` — 解決成功。stale だった場合は台帳内部で再保存済み
- `resolveFailed` — 登録はあるが解決に失敗（エラー表示の対象）

## VideoFileType（動画ファイル種別）

対応動画形式（mp4 / mov / m4v）の判定と `UTType` 一覧。純粋な値計算であり、永続化や seam を持たない。
旧 `VideoFileValidator` のうち検証部分のみがここに残る。
