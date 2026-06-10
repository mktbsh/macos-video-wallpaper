---
task: ブックマーク永続化 seam（DisplayWallpaperStore）
phase_or_step: "03-phase1"
created_at: 2026-06-10T11:45:00+09:00
---

# Phase 1 完了: VideoFileType 分離

- RED: `VideoFileTypeTests.swift` 新設（7 テスト）→ `cannot find 'VideoFileType' in scope` で失敗確認
- GREEN: `Sources/VideoFileType.swift` 新設（isSupported / allowedUTTypes / supportedExtensions を移動）
- 呼び出し置換 6 箇所: AppDelegate ×2 / StatusMenuController ×2 / WallpaperWindowController(DropDestinationView) ×2
- `VideoFileValidator` から種別検証と `UniformTypeIdentifiers` import を削除
- 旧 `VideoFileValidatorTests` から種別テスト 7 件を削除（移動済み）
- `xcodebuild test` 全グリーン確認済み
