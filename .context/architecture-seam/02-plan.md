---
task: ブックマーク永続化 seam（DisplayWallpaperStore）実装プラン
phase_or_step: "02-plan"
created_at: 2026-06-10T11:00:00+09:00
---

# DisplayWallpaperStore 実装プラン

## 前提（確定済み設計 = 01-design.md）

- `VideoFileValidator`（static ×12）を解体し、`DisplayWallpaperStoring` protocol（5 メソッド）を seam とする
- `resolveVideo` は `ResolvedVideo`（noVideo / resolved(URL) / resolveFailed）を返し、`hasBookmark` を吸収
- ファイル種別検証は純粋 enum `VideoFileType` へ分離
- codec（bookmark data 生成/解決/パス正規化）は `SecurityScopedBookmark` に集約し、adapter と PlaylistPersistence が共用
- UserDefaults キーは不変（データ移行なし）
- ブランチ: `feature/display-wallpaper-store`（現 HEAD = claude/improve から作成）

## Phase 1: VideoFileType 分離

使用 Skill: superpowers:test-driven-development

1. `Tests/VideoWallpaperTests/VideoFileTypeTests.swift` を新設し、`VideoFileValidatorTests` の種別テスト（isSupported ×6 / allowedUTTypes ×1）を `VideoFileType` 呼び出しに書き換えて移動 → 失敗確認
2. `Sources/VideoFileType.swift` を新設（`isSupported(extension:)` / `allowedUTTypes` を移動。`supportedExtensions` も移す）
3. 呼び出し置換: `AppDelegate.presentVideoOpenPanel`（2 箇所）、`StatusMenuController`（2 箇所）、`WallpaperWindowController` の DropDestinationView（2 箇所）
4. `VideoFileValidator` から種別検証を削除
5. `make build` 経由で xcodegen generate → `xcodebuild test` グリーン確認
6. artifact: `.context/architecture-seam/03-phase1.md`
7. コミット

## Phase 2: SecurityScopedBookmark codec 抽出

使用 Skill: superpowers:test-driven-development

1. `Sources/SecurityScopedBookmark.swift` を新設:
   - `static func data(for url: URL) throws -> Data`
   - `struct Resolution { let url: URL; let isStale: Bool }` と `static func resolve(_ data: Data) -> Resolution?`（解決 + `/private/` 正規化 + 存在確認。stale 再保存は**しない**——それは台帳の不変条件）
   - `static func normalizeFileURL(_:)`
2. テスト: 既存 `VideoFileValidatorTests` の codec 相当の検証を `SecurityScopedBookmarkTests` として新設（resolve 失敗で nil / 正規化 / 存在しないファイルで nil）。FS を使うテストは temp ディレクトリの実ファイルで行う（既存テストの手法を踏襲）
3. `PlaylistPersistence` の `VideoFileValidator.bookmarkData` / `resolveBookmarkData` 呼び出しを codec に置換（挙動不変: stale 再保存なしのまま）
4. テストグリーン確認 → artifact `.context/architecture-seam/04-phase2.md` → コミット

## Phase 3: DisplayWallpaperStore 本体（TDD）

使用 Skill: superpowers:test-driven-development

1. `Tests/VideoWallpaperTests/DisplayWallpaperStoreTests.swift` を新設（`@Suite(.serialized)` + suite-scoped UserDefaults + 前後 `removePersistentDomain` 掃除）。既存の per-display bookmark / enabled テストを protocol 経由の検証に書き換えて移し、新規に以下を追加:
   - `resolveVideo` が未登録で `.noVideo`
   - 登録後にファイル削除で `.resolveFailed`
   - stale bookmark 解決時に再保存される（保存 payload が更新される）— codec 注入（下記 2）で `isStale=true` を返す fake codec を使う
   - `saveVideo` 失敗で `false` — codec 注入で throw する fake codec を使う
   - UserDefaults キー形式が現行（`videoBookmark` per-display key / `displayEnabled` prefix）と一致 — データ互換の受け入れ条件
2. `Sources/DisplayWallpaperStore.swift` を新設: `ResolvedVideo` / `DisplayWallpaperStoring` / `final class DisplayWallpaperStore`。
   - public init: `init(defaults: UserDefaults = .standard)`
   - テスト用 codec 注入: internal init で `makeBookmarkData: (URL) throws -> Data` / `resolveBookmarkData: (Data) -> SecurityScopedBookmark.Resolution?` を受け取り、production default は `SecurityScopedBookmark.data(for:)` / `SecurityScopedBookmark.resolve(_:)` とする（stale / 生成失敗を deterministic にテストするため）。公開 API は `init(defaults:)` のみとし、codec 注入 init は internal・テスト専用に限定する（過剰な seam 化はしない）
   - key 定数（`bookmarkKey` / `displayEnabledKeyPrefix`）はここに置く
3. `PlaylistPersistence` の legacy 経路（旧 `resolveBookmarkedURL(defaults:)` / `clearBookmark(defaults:)` 相当）は PlaylistPersistence 内の private helper に移す。key 所有は次で確定:
   - PlaylistPersistence に `private static let legacyBookmarkKey = "videoBookmark"` / `private static let legacyPathKey = "videoFilePath"` を置く（legacy 単一 bookmark の migrate / clear の唯一の消費者。`DisplayWallpaperStore.bookmarkKey` への依存は作らない——per-display prefix と legacy global key は同じ文字列だが別概念）
   - `PlaylistPersistenceTests` の legacy arrange（旧 `VideoFileValidator.saveBookmark(for:defaults:)` 利用箇所）は `SecurityScopedBookmark.data(for:)` + key 直接 set に更新する
   - `DisplayIdentifierTests` の `VideoFileValidator.bookmarkKey` 参照は `DisplayWallpaperStore.bookmarkKey` に更新
4. テストグリーン → artifact `.context/architecture-seam/05-phase3.md` → コミット

## Phase 4: AppDelegate 注入・置換・VideoFileValidator 削除（TDD）

使用 Skill: superpowers:test-driven-development

1. テスト先行: `Tests/VideoWallpaperTests/Support/InMemoryDisplayWallpaperStore.swift` に fake（`[DisplayIdentifier: URL]` + enabled 辞書 + resolve 結果の上書き用プロパティ + save 失敗フラグ）を新設し、AppDelegate オーケストレーションテストを新設。
   **テストからの呼び出し方法（確定）**: `handleVideoSelected` / `handleVideoCleared` / `handleDisplayToggled` / `buildDisplayStates` / `loadVideoForDisplay` の 5 メソッドだけを**新しい internal extension に切り出し**、`@testable import` で直接呼ぶ。playlist editor 系 helper を含む既存 `private extension` はそのまま private 維持（必要以上に internal 化しない）。StatusMenuController の factory seam 追加はしない（候補 6 のスコープであり、本タスクでは seam を増やさない）。`handleVideoSelected` は fake controller の `onVideoDropped` 経由の検証も 1 本入れ、production 配線が生きていることを確認する。テスト項目:
   - `handleVideoSelected`: save 成功 → エラー解除・対象 controller に load・menu state 更新 / save 失敗 → `.bookmarkSaveFailed` が menu state の errorMessage に出る
   - `loadVideoForDisplay`: `.resolveFailed` → `.bookmarkResolveFailed` + `clearVideo` / `.noVideo` → エラーなしで `clearVideo`
   - `buildDisplayStates`: `.resolveFailed` の display で `errorMessage` が `.bookmarkResolveFailed` のローカライズ文言になる
   - `handleVideoCleared`: 台帳 clear + エラー解除 + menu 更新
   - `handleDisplayToggled`: `setEnabled` 反映で controller が再構成される
   - 既存 `AppDelegateScreenLifecycleTests` のうち `UserDefaults.standard` を直接 arrange/defer 掃除している箇所（display enabled / bookmark 系）は**すべて** fake 注入に置換する（DimLevel / PowerSavingMode 等、本 seam の対象外の UserDefaults は現状維持）
2. `AppDelegate.init` に `displayWallpaperStore: any DisplayWallpaperStoring = DisplayWallpaperStore()` を追加し、以下の 8 call site を store 経由に置換:
   - `setupWallpaperWindows` L136 `isDisplayEnabled` → `store.isEnabled`
   - `loadVideoForDisplay` L216 `resolveBookmarkedURL` + L220 `hasBookmark` → `switch store.resolveVideo(for:)`（2 呼び出し → 1 switch）
   - `buildDisplayStates` L242 `isDisplayEnabled` / L243 `resolveBookmarkedURL` → `store.isEnabled` / `store.resolveVideo`
   - `handleVideoSelected` L256 `saveBookmark` → `store.saveVideo`
   - `handleVideoCleared` L271 `clearBookmark` → `store.clearVideo`
   - `handleDisplayToggled` L278 `setDisplayEnabled` → `store.setEnabled`
3. `Sources/VideoFileValidator.swift` と `VideoFileValidatorTests.swift` の残骸を削除（参照ゼロを grep で確認）
4. `xcodebuild test` 全グリーン + `make build` 成功確認
5. artifact: `.context/architecture-seam/06-phase4.md` → コミット

## Phase 5: ドキュメント・ADR・PR

使用 Skill: superpowers:verification-before-completion（完了宣言前の検証）、commit-commands:commit-push-pr（docs コミット + push + main 向け PR 作成）
※ レビュアー提案の `github:yeet` は本セッションの利用可能 skill に存在しないため、実在する上記 2 skill で代替（substance は同一: 検証してから push / PR）。Phase 5 着手時に skill availability を再確認し、不可なら `git` / `gh pr create` を直接実行する

1. `docs/adr/2026-06-10-display-wallpaper-store-seam.md` を作成（背景=アーキテクチャレビュー候補 1、決定=01-design の内容、日時とモデル名 Claude Fable 5 を記載——モデル名記載はグローバルルール必須項目）。01-design からの差分として「legacy global key と per-display key は同じ文字列 `videoBookmark` でも別概念であり、key 定数は共有しない」を明記
2. `tasks/knowledge.md` に「設定値 enum パターン」周辺の整合確認 + 今回の学びを追記、`tasks/todo.md` の関連項目を更新（bookmark resolve の seam 化により可能になった P1 テスト項目への言及）
3. `CLAUDE.md` のファイル構成表を更新（VideoFileValidator → VideoFileType / DisplayWallpaperStore / SecurityScopedBookmark）
4. push → main 向け PR 作成
5. artifact: `.context/architecture-seam/07-phase5.md`

## 受け入れ条件

- `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'` 全グリーン
- `make build` 成功（xcodegen generate を含む。新規 Swift ファイルの project 統合を最終条件として固定）
- `VideoFileValidator` への参照が Sources/Tests からゼロ
- UserDefaults キー形式が変更前と一致（テストで固定）
- AppDelegate の 4 オーケストレーション経路が fake store で検証されている
- `buildDisplayStates` が `.resolveFailed` を `errorMessage` に反映することがテストされている
- PlaylistPersistence の legacy single bookmark migration / clear のテスト（`PlaylistPersistenceTests` 既存分）が `SecurityScopedBookmark` + private helper 移行後もグリーンのまま維持されている
- 既存ユーザーのデータ移行は発生しない

## スコープ外（理由つき）

- `buildDisplayStates` が menu 更新ごとに resolve する性能問題（todo P2 に既載。seam 化で観測可能になるが、修正は別タスク）
- PlaybackSession 統合（候補 2）・設定モジュール（候補 3）は後続
- StatusMenuController 側の callback 検証テスト（候補 6 のスコープ）
