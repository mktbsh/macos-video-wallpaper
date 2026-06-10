---
title: ドメイン用語集
updated: 2026-06-10
---

# CONTEXT — ドメイン用語集

アーキテクチャレビュー・設計会話で使う、このプロジェクト固有の用語。
コード・テスト・ドキュメントではこの語彙を使い、同義語への言い換えをしないこと。

## DisplayWallpaperStore（画面壁紙台帳）

画面（`DisplayIdentifier`）ごとの壁紙構成——「どの動画を表示するか」「その画面で壁紙が有効か」——を永続化する台帳。
security-scoped bookmark の生成・解決・stale 再保存・`/private/` パス正規化は台帳の implementation 内の関心事であり、caller には見せない。

- protocol: `DisplayWallpaperStoring`（seam）
- production adapter: `DisplayWallpaperStore`（UserDefaults + security-scoped bookmark）
- test adapter: in-memory fake

## ResolvedVideo（動画解決結果）

台帳に問い合わせた結果の 3 状態。「未登録」と「登録はあるが解決失敗（ファイル消失等）」を caller が 1 回の呼び出しで区別できる。

- `noVideo` — その画面に動画が登録されていない
- `resolved(URL)` — 解決成功。stale だった場合は台帳内部で再保存済み
- `resolveFailed` — 登録はあるが解決に失敗（エラー表示の対象）

## VideoFileType（動画ファイル種別）

対応動画形式（mp4 / mov / m4v）の判定と `UTType` 一覧。純粋な値計算であり、永続化や seam を持たない。
旧 `VideoFileValidator` のうち検証部分のみがここに残る。
