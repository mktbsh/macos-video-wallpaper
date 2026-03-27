# Playlist Persistence and Auto-Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** playlist を永続化して前回の current item から復元できるようにし、その上で動画全体または loop range を 1 周したら次の動画へ自動ローテーションさせる。

**Architecture:** `codex/playlist-persistence` では `PlaylistPersistence` が `PlaylistStore` の state を bookmark ベースで `UserDefaults` に保存・復元し、`AppDelegate` が起動時復元と保存トリガーを配線する。`codex/playlist-auto-rotation` では `AVPlayerLooper` を単発再生へ置き換え、`WallpaperWindowController` が token 付き完了通知を返し、`AppDelegate` が `MainActor` 上で completion を 1 回だけ消費して次 item を適用する。

**Tech Stack:** Swift, Cocoa, AVFoundation, Swift Testing, UserDefaults

---

## File Map

| ファイル | 変更内容 |
|---------|---------|
| `Sources/PlaylistModels.swift` | Branch 1 では persistence から使う bridge を追加。Branch 2 では manual 操作と completion 操作の API を分離する |
| `Sources/AppDelegate.swift` | Branch 1 では playlist 復元と保存トリガー配線。Branch 2 では current playback token と completion handling を追加 |
| `Sources/PlaylistPersistence.swift` | 新規。persisted state の encode/decode、legacy migration、bookmark 解決を担当 |
| `Sources/WallpaperWindowController.swift` | Branch 2 で `AVPlayerLooper` を外し、単発再生 + completion callback + same-target replay 制御へ変更 |
| `Sources/PlaybackCompletion.swift` | 新規。token と item 識別子を持つ完了通知の値型 |
| `Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift` | 新規。保存・復元・移行・破損 state fallback を検証 |
| `Tests/VideoWallpaperTests/PlaylistStoreTests.swift` | Branch 1/2 でメモリ上の manual 操作と current 維持の検証を更新 |
| `Tests/VideoWallpaperTests/RotationEngineTests.swift` | Branch 2 で completion token の advance と stale callback 無視を検証 |
| `Tests/VideoWallpaperTests/LocalizationCatalogTests.swift` | playlist 周辺の文言変更があれば追随 |
| `project.yml` | 新規 source/test file を project に含める |
| `VideoWallpaper.xcodeproj/project.pbxproj` | `xcodegen generate` で再生成 |
| `tasks/todo.md` | 完了タスクの反映 |
| `tasks/knowledge.md` | 実装中に得た学びを追記 |

---

## Branch 1: `codex/playlist-persistence`

### Task 1: `PlaylistPersistence` の失敗するテストを先に追加

**Files:**
- Create: `Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift`

- [ ] **Step 1: `PlaylistPersistenceTests` の雛形を追加**

`Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift` を新規作成し、`@Suite(.serialized)` を付ける。最低限、以下のテスト名で失敗するテストを置く。

```swift
@Suite(.serialized)
struct PlaylistPersistenceTests {
    @Test func save_and_restore_playlist_state() throws
    @Test func restore_filters_out_invalid_bookmarks() throws
    @Test func restore_falls_back_to_first_item_when_current_id_is_missing() throws
    @Test func migrate_legacy_single_bookmark_to_playlist_state() throws
    @Test func corrupt_playlist_state_falls_back_to_legacy_once() throws
    @Test func clear_removes_playlist_state_and_legacy_bookmark() throws
}
```

- [ ] **Step 2: 新規テストだけを実行して RED を確認**

Run:

```bash
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/PlaylistPersistenceTests
```

Expected: `PlaylistPersistence` 未実装、または参照シンボル未定義で fail

- [ ] **Step 3: コミットはまだしない**

このタスクでは RED まで。実装後にまとめて commit する。

### Task 2: `PlaylistPersistence` を実装して `AppDelegate` に統合

**Files:**
- Create: `Sources/PlaylistPersistence.swift`
- Modify: `Sources/PlaylistModels.swift`
- Modify: `Sources/AppDelegate.swift`
- Modify: `project.yml`

- [ ] **Step 1: 保存用の値型を `Sources/PlaylistPersistence.swift` に追加**

以下の責務を持つ値型/サービスを追加する。

- `PersistedPlaylistEntry`
- `PersistedPlaylistState`
- `PlaylistPersistence`

`PlaylistPersistence` の public API は plan 時点では以下に揃える。

```swift
struct PlaylistPersistence {
    func load() -> PlaylistStore
    func save(store: PlaylistStore)
    func clear()
}
```

内部では `UserDefaults` キーを 1 つに固定し、bookmark の生成・復元・legacy migration を扱う。

- [ ] **Step 2: legacy migration と corrupt state fallback を実装**

仕様に従い、以下を実装する。

- `playlistState` がなければ `videoBookmark` から 1-item playlist を生成
- migration 成功後は `videoBookmark` を削除
- `playlistState` が壊れていれば 1 回だけ legacy bookmark に fallback
- empty `playlistState` は正規状態として扱い、legacy へ fallback しない
- clear 時は `playlistState` と `videoBookmark` を両方消す
- migration 後と通常保存フローでは `videoBookmark` を二度と更新しない

- [ ] **Step 3: `PlaylistStore` に persistence から使う bridge を足す**

`Sources/PlaylistModels.swift` で、以下を persistence 実装から使いやすい形に整える。

- `items`
- `currentItem`
- current item を指定した `init`
- playlist を丸ごと差し替える API

Branch 1 では manual 操作の挙動は変えない。

- [ ] **Step 4: `AppDelegate` に load/save 配線を追加**

起動時:

- `PlaylistPersistence.load()` で `playlistStore` を復元

保存トリガー:

- `replacePlaylist`
- `presentVideoOpenPanel` の追加 path
- `advanceToNextItem`
- `moveToPreviousItem`
- `clearPlaylist`
- editor 由来の `delete/move/setCurrent/updateDisplayName/updateUseFullVideo/updateStartTime/updateEndTime`

保存は `PlaylistStore` 変更直後に呼び、UI 再描画より前でも後でもよいが、呼び出し位置は全経路で統一する。Branch 1 のこの step で、既存の `VideoFileValidator.saveBookmark` を current item 変更フローから外し、playlist 保存だけを source of truth にする。

- [ ] **Step 5: `project.yml` を更新して新規 file を project に含める**

`Sources/PlaylistPersistence.swift` と `Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift` が Xcode project に入るようにする。

- [ ] **Step 6: `xcodegen generate` を実行**

Run:

```bash
xcodegen generate
```

Expected: `project.pbxproj` が再生成され、新規 file が含まれる

- [ ] **Step 7: Branch 1 の対象テストを実行して GREEN を確認**

Run:

```bash
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/PlaylistPersistenceTests -only-testing:VideoWallpaperTests/PlaylistStoreTests -only-testing:VideoWallpaperTests/VideoFileValidatorTests
```

Expected: PASS

- [ ] **Step 8: フル検証**

Run:

```bash
./scripts/run-swiftlint-from-spm.sh
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS'
```

Expected: lint/test ともに PASS

- [ ] **Step 9: `tasks/todo.md` / `tasks/knowledge.md` を更新**

反映内容:

- `プレイリストを永続化して再起動後も復元する` を `[x]`
- persistence 実装で得た知見を `knowledge` に追記

- [ ] **Step 10: Branch 1 をコミット**

```bash
git add Sources/PlaylistPersistence.swift Sources/PlaylistModels.swift Sources/AppDelegate.swift Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift project.yml VideoWallpaper.xcodeproj/project.pbxproj tasks/todo.md tasks/knowledge.md
git commit -m "Persist playlist state across launches"
```

---

## Branch 2: `codex/playlist-auto-rotation`

### Task 3: stacked branch を切り、token API を分離する

**Files:**
- Modify: `Sources/PlaylistModels.swift`
- Modify: `Sources/RotationEngine.swift`
- Modify: `Tests/VideoWallpaperTests/PlaylistStoreTests.swift`
- Modify: `Tests/VideoWallpaperTests/RotationEngineTests.swift`

- [ ] **Step 1: Branch 1 commit の上に stacked branch を作る**

Run:

```bash
git switch -c codex/playlist-auto-rotation
```

Expected: `codex/playlist-auto-rotation` が `codex/playlist-persistence` の HEAD を親に持つ

- [ ] **Step 2: token 分離の失敗するテストを追加**

`RotationEngineTests` / `PlaylistStoreTests` に以下を追加する。

- manual `next()` / `previous()` / `setCurrent(id:)` は token なしで current を変更できる
- `advanceAfterPlaybackCompletion(using:)` は current token でだけ進む
- stale token は current を変えない
- single item でも `advanceAfterPlaybackCompletion(using:)` は `true` を返し current item を維持する
- completion ベースの advance でも末尾から先頭へ wrap する

- [ ] **Step 3: 対象テストだけを実行して RED を確認**

Run:

```bash
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/RotationEngineTests -only-testing:VideoWallpaperTests/PlaylistStoreTests
```

Expected: 新 API 未実装で fail

- [ ] **Step 4: `RotationEngine` / `PlaylistStore` を実装**

設計どおり以下に分ける。

- manual:
  - `next()`
  - `previous()`
  - `setCurrent(id:)`
- completion:
  - `beginPlayback()`
  - `advanceAfterPlaybackCompletion(using:)`

`PlaylistStore` は playback token を保持しない。manual 操作後は `AppDelegate` が `applyCurrentPlaylistItem()` を呼んで新 token を発行する前提にする。

- [ ] **Step 5: 対象テストを再実行して GREEN を確認**

Run:

```bash
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/RotationEngineTests -only-testing:VideoWallpaperTests/PlaylistStoreTests
```

Expected: PASS

### Task 4: `WallpaperWindowController` を単発再生 + completion 通知へ置き換える

**Files:**
- Create: `Sources/PlaybackCompletion.swift`
- Modify: `Sources/WallpaperWindowController.swift`
- Modify: `project.yml`

- [ ] **Step 1: `PlaybackCompletion` と controller の受け皿を先に追加し、ビルドを RED にする**

`WallpaperWindowController` は UI/AVFoundation 依存が強いので、ここではテストより先に型と API を固定する。`PlaybackCompletion` の値型、`onPlaybackFinished`、token 付き playback context を先に追加し、未更新の call site がコンパイルエラーになる状態を RED とみなす。

```swift
struct PlaybackCompletion: Equatable {
    let itemID: PlaylistItem.ID
    let token: RotationEngine<PlaylistItem>.PlaybackToken
}
```

Run:

```bash
xcodebuild build -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS'
```

Expected: `AppDelegate` など未更新 call site のコンパイルエラー

- [ ] **Step 2: `AVPlayerLooper` を外し、単発再生モデルへ変更**

`WallpaperWindowController` で以下を行う。

- `playerLooper` を削除
- current playback context に `itemID` と `token` を保持
- `load(...)` は `URL + timeRange + token` が一致しない限り毎回新しい `AVPlayerItem` をセットする
- `useFullVideo == false` なら `seek(to:)` + `forwardPlaybackEndTime`
- `AVPlayerItemDidPlayToEndTime` を監視して current context と一致する completion だけ通知

single-item wrap や duplicate entry を壊さないため、`URL + timeRange` が同じでも token が変われば no-op にしない。

- [ ] **Step 3: battery-saving / occlusion 挙動を維持**

確認ポイント:

- `pausePlayback()` は window を隠して再生停止する
- `resumePlayback()` は current item があれば再開する
- occlusion observer は visible 時だけ `play()` する

- [ ] **Step 4: `project.yml` を更新し、`xcodegen generate` を実行**

Run:

```bash
xcodegen generate
```

### Task 5: `AppDelegate` で completion を 1 回だけ消費して次へ進める

**Files:**
- Modify: `Sources/AppDelegate.swift`
- Modify: `Tests/VideoWallpaperTests/RotationEngineTests.swift`
- Optionally Create: `Tests/VideoWallpaperTests/PlaybackCompletionTests.swift`

- [ ] **Step 1: `AppDelegate` に current playback token を追加**

追加する状態:

- `currentPlaybackToken`

`applyCurrentPlaylistItem()` のたびに:

- `playlistStore.beginPlayback()` で新 token を発行
- current item の `itemID`, `url`, `timeRange`, `token` を全画面へ渡す

`setupWallpaperWindows()` で新しい controller を作ったときも、playlist が空でなければ `applyCurrentPlaylistItem()` を通して current item を流す。起動時復元と画面再構成の両方で、token なしの直接 `load(...)` を残さない。

- [ ] **Step 2: manual 操作の後に新 token を発行する path を揃える**

対象:

- `advanceToNextItem`
- `moveToPreviousItem`
- `setCurrentPlaylistItem`
- drag & drop による `replacePlaylist`

manual の current 変更後は必ず `applyCurrentPlaylistItem()` を通す。

- [ ] **Step 3: completion handler を MainActor 直列で処理**

`WallpaperWindowController.onPlaybackFinished` の handler で以下を実装する。

1. `completion.token == currentPlaybackToken` を確認
2. 一致したら `playlistStore.advanceAfterPlaybackCompletion(using: token)` を呼ぶ
3. `true` の場合はその場で persistence に save し、その後 `applyCurrentPlaylistItem()` を呼んで新 token を発行
4. 後続の duplicate completion は stale token として落ちる

- [ ] **Step 4: completion flow を検証するテストを追加**

最低限:

- current token でだけ advance する
- stale completion は無視する
- single item でも advance path が動き、再生が再スタートする前提の state になる
- completion 経由でも末尾から先頭へ wrap する

可能なら `AppDelegate` ではなく `RotationEngine` / `PlaylistStore` に閉じたテストで担保し、UI 依存は薄く保つ。

- [ ] **Step 5: Branch 2 の対象テストを実行して GREEN を確認**

Run:

```bash
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/RotationEngineTests -only-testing:VideoWallpaperTests/PlaylistStoreTests
```

Expected: PASS

- [ ] **Step 6: フル検証**

Run:

```bash
./scripts/run-swiftlint-from-spm.sh
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS'
```

Expected: lint/test ともに PASS

- [ ] **Step 7: `tasks/todo.md` / `tasks/knowledge.md` を更新**

反映内容:

- `再生完了をトリガーに次の動画へ自動ローテーションする` を `[x]`
- completion token / same-target replay / single-pass playback に関する学びを追記

- [ ] **Step 8: Branch 2 をコミット**

```bash
git add Sources/PlaybackCompletion.swift Sources/WallpaperWindowController.swift Sources/AppDelegate.swift Sources/PlaylistModels.swift Sources/RotationEngine.swift Tests/VideoWallpaperTests/PlaylistStoreTests.swift Tests/VideoWallpaperTests/RotationEngineTests.swift project.yml VideoWallpaper.xcodeproj/project.pbxproj tasks/todo.md tasks/knowledge.md
git commit -m "Rotate playlist automatically on playback completion"
```

---

## Final Verification

- [ ] **Step 1: Branch 1 と Branch 2 の差分を再確認**

Run:

```bash
git log --oneline --decorate --graph -5
git diff main...HEAD --stat
```

Expected: stacked branch 構成が見える

- [ ] **Step 2: 最終 lint / test**

Run:

```bash
./scripts/run-swiftlint-from-spm.sh
xcodebuild test -project VideoWallpaper.xcodeproj -scheme VideoWallpaper -destination 'platform=macOS'
```

Expected: PASS

- [ ] **Step 3: push / PR**

Branch 1:

```bash
git push -u origin codex/playlist-persistence
```

Branch 2:

```bash
git push -u origin codex/playlist-auto-rotation
```

PR は stacked で作る。

- `codex/playlist-persistence` -> `main`
- `codex/playlist-auto-rotation` -> `codex/playlist-persistence`
