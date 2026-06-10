---
task: ブックマーク永続化 seam（DisplayWallpaperStore）
phase_or_step: "04-phase2"
created_at: 2026-06-10T12:05:00+09:00
---

# Phase 2 完了: SecurityScopedBookmark codec 抽出

- RED: `SecurityScopedBookmarkTests.swift` 新設（7 テスト: roundtrip / invalid data / 消失ファイル / fresh は非 stale / normalize ×3）→ `cannot find 'SecurityScopedBookmark'` で失敗確認
- GREEN: `Sources/SecurityScopedBookmark.swift` 新設。`data(for:)` / `resolve(_:) -> Resolution?`（url + isStale。stale 再保存はしない）/ `normalizeFileURL`
- `PlaylistPersistence` の `VideoFileValidator.bookmarkData` / `resolveBookmarkData` 呼び出し 3 箇所を codec に置換（挙動不変）
- `xcodebuild test` 全グリーン確認済み
- 残: `PlaylistPersistenceTests` の `VideoFileValidator` 参照は Phase 3/4 で更新
