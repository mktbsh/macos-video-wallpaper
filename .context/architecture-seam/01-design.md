---
task: ブックマーク永続化 seam（DisplayWallpaperStore）設計
phase_or_step: "01-design"
created_at: 2026-06-10T10:50:00+09:00
---

# DisplayWallpaperStore 設計（grilling 結果）

## ユーザー確定事項

1. スコープ: ブックマーク台帳 + 画面有効フラグを 1 モジュールに（codec は含めない）
2. resolve は結果 enum（`ResolvedVideo`）に深め、`hasBookmark` を削除
3. ファイル種別検証は純粋モジュール `VideoFileType` へ分離。`VideoFileValidator` の名前は廃止
4. 命名: `DisplayWallpaperStore`（CONTEXT.md に記録済み）

## interface 案

```swift
enum ResolvedVideo: Equatable {
    case noVideo
    case resolved(URL)
    case resolveFailed
}

protocol DisplayWallpaperStoring: AnyObject {
    func resolveVideo(for display: DisplayIdentifier) -> ResolvedVideo
    @discardableResult
    func saveVideo(_ url: URL, for display: DisplayIdentifier) -> Bool
    func clearVideo(for display: DisplayIdentifier)
    func isEnabled(_ display: DisplayIdentifier) -> Bool
    func setEnabled(_ enabled: Bool, for display: DisplayIdentifier)
}
```

- 命名規約は既存 `WallpaperWindowControlling` に合わせ protocol を -ing 形に
- `saveVideo` の失敗は Bool（現行 `saveBookmark` と同じ。AppDelegate はこれでエラー状態を立てる）
- stale 再保存・`/private/` 正規化・FileManager 存在確認は implementation の不変条件

## 分解先

| 旧 VideoFileValidator の要素 | 行き先 |
|---|---|
| isSupported / allowedUTTypes | `VideoFileType`（純粋 enum、新ファイル） |
| per-display save/clear/resolve/has | `DisplayWallpaperStore`（has は ResolvedVideo に吸収） |
| isDisplayEnabled / setDisplayEnabled | `DisplayWallpaperStore` |
| bookmarkData / resolveBookmarkData / normalizeFileURL | `SecurityScopedBookmark`（codec。PlaylistPersistence と adapter が共用） |
| legacy 単一 bookmark (videoBookmark / videoFilePath) resolve+migration | PlaylistPersistence の legacy migration 経路に残置（唯一の消費者） |
| key 定数 (bookmarkKey 等) | adapter 内。PlaylistPersistence から参照 |

## 注入

- `AppDelegate.init` に `displayWallpaperStore: any DisplayWallpaperStoring = DisplayWallpaperStore()` を追加
- 既存 UserDefaults キーは不変（データ移行なし）

## テスト移行

- VideoFileValidatorTests の種別テスト → VideoFileTypeTests（assertion 据え置き）
- bookmark / enabled テスト → DisplayWallpaperStore adapter テスト（suite-scoped defaults 維持）
- 新規: in-memory fake による AppDelegate オーケストレーションテスト
  - handleVideoSelected: save 成功/失敗 → エラー状態・reload・menu 更新
  - handleVideoCleared / handleDisplayToggled
  - buildDisplayStates: resolveFailed → errorMessage
- 既知の残課題（スコープ外、todo P2 既載）: buildDisplayStates が更新ごとに resolve する性能問題
