---
title: DisplayWallpaperStore seam の導入と VideoFileValidator の解体
date: 2026-06-10
status: accepted
author: Claude Fable 5 (claude-fable-5)
---

# DisplayWallpaperStore seam の導入と VideoFileValidator の解体

## 背景

アーキテクチャレビュー（2026-06-10）で、`VideoFileValidator` が 3 つの別概念
（ファイル種別検証 / 画面ごとのブックマーク台帳 / 生の bookmark codec）を
12 個の public static メソッドに同居させた浅い namespace であることが分かった。
seam が無いため、これを直接呼ぶ AppDelegate の 4 つのオーケストレーション経路
（動画選択・解除・画面トグル・menu state 構築）が実 FS と `UserDefaults.standard`
に縛られ、すべて未テストだった。

## 決定

1. **`DisplayWallpaperStoring` protocol（5 メソッド）を seam とする。**
   「画面ごとの壁紙構成（どの動画を表示するか・有効か）」を 1 概念として台帳化。
   production adapter は `DisplayWallpaperStore`（UserDefaults + security-scoped bookmark）、
   テスト adapter は `InMemoryDisplayWallpaperStore`。
2. **resolve は `ResolvedVideo`（noVideo / resolved / resolveFailed）を返す。**
   「未登録」と「登録はあるが解決失敗」の区別を 1 呼び出しで返し、旧 `hasBookmark` を吸収。
   stale bookmark の再保存・`/private/` パス正規化・存在確認は implementation の不変条件。
3. **ファイル種別検証は純粋 enum `VideoFileType` に分離。**
4. **bookmark の生成・解決は `SecurityScopedBookmark` codec に集約。**
   codec は stale 再保存をしない（それは台帳の責務）。
   adapter と `PlaylistPersistence` が共用する。
5. **legacy global key と per-display key は同じ文字列 `videoBookmark` でも別概念であり、
   key 定数は共有しない。** legacy 単一壁紙の migrate / clear は唯一の消費者である
   `PlaylistPersistence` の private 定数・helper に置く。
6. **UserDefaults キー形式は不変。** 既存ユーザーのデータ移行は発生しない
   （キー互換はテストで固定）。
7. protocol / adapter に `@MainActor` は付けない。UserDefaults はスレッドセーフであり、
   非 MainActor のテストから同期的に呼べる方が簡潔。

## 影響

- AppDelegate の 4 オーケストレーション経路が fake store で初めてテスト可能になった
  （`AppDelegateWallpaperStoreTests`）。
- `VideoFileValidator` は削除。今後の bookmark 関連変更は `DisplayWallpaperStore` /
  `SecurityScopedBookmark` に局所化される。
- ドメイン用語（DisplayWallpaperStore / ResolvedVideo / VideoFileType）は
  ルートの `CONTEXT.md` に記録した。
- 後続候補: PlaybackSession の AppDelegate 統合（tasks/todo.md P1）は本 seam の
  fake を前提にテストを書ける。
