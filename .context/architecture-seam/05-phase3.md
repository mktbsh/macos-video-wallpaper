---
task: ブックマーク永続化 seam（DisplayWallpaperStore）
phase_or_step: "05-phase3"
created_at: 2026-06-10T12:30:00+09:00
---

# Phase 3 完了: DisplayWallpaperStore 本体

- RED: `DisplayWallpaperStoreTests.swift` 新設（16 テスト）→ `cannot find 'DisplayWallpaperStore'` で失敗確認
- GREEN: `Sources/DisplayWallpaperStore.swift` 新設
  - `ResolvedVideo`（noVideo / resolved / resolveFailed）
  - `DisplayWallpaperStoring` protocol（5 メソッド）
  - production adapter: `convenience init(defaults:)` + テスト専用 codec 注入 init（internal）
  - stale 再保存・key 互換（`videoBookmark` / `displayEnabled`）をテストで固定
- 設計判断の変更: protocol / class への `@MainActor` 付与をやめた（UserDefaults はスレッドセーフで、非 MainActor のテストから同期的に呼べる方が簡潔。AppDelegate からの利用は MainActor 上の同期呼び出しで問題なし）
- `PlaylistPersistence` に legacy helper（`resolveLegacyBookmarkedURL` / `clearLegacyBookmark`）と private key 定数を移設。legacy 解決時の bookmark 書き込みは廃止（直後の `save(store:)` が key を削除するため net 挙動は不変）
- テスト参照更新: `PlaylistPersistenceTests`（arrange を codec 直接 set に）/ `DisplayIdentifierTests`（`DisplayWallpaperStore.bookmarkKey` に）
- `xcodebuild test` 全グリーン確認済み
