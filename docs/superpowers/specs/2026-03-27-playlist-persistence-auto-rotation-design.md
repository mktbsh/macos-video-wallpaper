# Playlist Persistence and Auto-Rotation Design

## Summary

未実装の 2 機能を、依存順に合わせて 2 本の stacked branch で実装する。

1. `codex/playlist-persistence`
   プレイリスト永続化と起動時復元を追加する。
2. `codex/playlist-auto-rotation`
   再生完了ベースの自動ローテーションを追加する。

どちらも既存の `PlaylistItem` / `PlaylistStore` / `RotationEngine` を中心に組み立て、UI 側は source of truth を持たない。

## Goals

- playlist 全体を再起動後も復元できる
- 前回の `current item` から再開できる
- 単一 bookmark 保存から playlist 保存へ安全に移行できる
- 動画全体でも loop range でも、「有効な再生区間を 1 周したら次へ進む」を実現する
- playlist が 1 件でも末尾でも、先頭へ戻って無限回転する

## Non-Goals

- 複数画面ごとに別 playlist を持つ
- 再生位置の途中秒数まで復元する
- playlist 永続化の保存先を `UserDefaults` 以外へ広げる
- time range 編集 UI の大幅な再設計

## Branch Strategy

### Branch 1: `codex/playlist-persistence`

責務:

- playlist 全体の保存
- 起動時復元
- legacy 単一 bookmark からの移行
- `currentItemID` の復元

この branch では、自動ローテーションは追加しない。手動の `Next` / `Previous` と current item の復元までを扱う。

### Branch 2: `codex/playlist-auto-rotation`

ベース:

- `codex/playlist-persistence`

責務:

- 再生完了通知
- playback token を使った stale completion の無視
- current item の advance
- 末尾から先頭への wrap

この branch では、新しい保存形式は増やさない。Branch 1 の永続化済み state をそのまま使う。

## Architecture

### Current State

- `PlaylistItem` は `displayName`, `useFullVideo`, `startTime`, `endTime` を持つ
- `PlaylistStore` はメモリ上の playlist state と `RotationEngine` を持つ
- `WallpaperWindowController` は `load(videoURL:timeRange:)` で `AVPlayerLooper` を組み立てる
- `AppDelegate` が playlist state と UI 再適用の中心にいる

### Target State

- 永続化は `PlaylistPersistence` に分離する
- `PlaylistStore` はメモリ上の state machine に専念する
- `WallpaperWindowController` は「1 セグメントを再生して完了を通知する」責務に寄せる
- `AppDelegate` が persistence 読み書きと current playback token の配線を持つ

## Data Model

### PersistedPlaylistEntry

保存用の値型を追加する。

- `id: UUID`
- `bookmarkData: Data`
- `displayName: String`
- `useFullVideo: Bool`
- `startTime: Double?`
- `endTime: Double?`

`PlaylistItem` の `url` は直接保存せず、security-scoped bookmark として保持する。

### PersistedPlaylistState

- `entries: [PersistedPlaylistEntry]`
- `currentItemID: UUID?`

`Codable` で 1 つの `UserDefaults` キーに全量保存する。playlist 件数は小さい前提なので、操作ごとに全量書き戻してよい。

### PlaylistPersistence

責務:

- `PlaylistStore` の current state を保存する
- `PersistedPlaylistState` を復元して `[PlaylistItem] + currentItemID` に戻す
- legacy 単一 bookmark を 1-item playlist に移行する

責務外:

- UI 更新
- playback token 管理
- `startAccessingSecurityScopedResource()` の開始

### PlaylistStore API Changes

Branch 1 では、保存対象を読み出すための薄い bridge を追加する。

- `var items: [PlaylistItem]`
- `var currentItem: PlaylistItem?`
- `var summary: PlaylistSummary?`

Branch 2 では、`RotationEngine` の token 制御を上位へ渡すための薄い API を追加する。

- `mutating func beginPlayback() -> RotationEngine<PlaylistItem>.PlaybackToken`
- `mutating func next(using token: RotationEngine<PlaylistItem>.PlaybackToken) -> Bool`
- `mutating func previous(using token: RotationEngine<PlaylistItem>.PlaybackToken) -> Bool`

`PlaylistStore` 自体は token の所有者にならず、current playback token は `AppDelegate` 側が持つ。

## Persistence Flow

### Save

保存トリガー:

- playlist 置換
- item 追加
- item 削除
- item 並び替え
- current item 変更
- 表示名変更
- loop range 変更
- playlist clear

保存手順:

1. `PlaylistStore.items` と `currentItem?.id` から `PersistedPlaylistState` を組み立てる
2. 各 item の `url` から `bookmarkData(options: .withSecurityScope)` を作る
3. `UserDefaults` に encode して書き込む

保存失敗時は UI エラーにしない。メモリ上の playlist は維持し、ログだけ残す。

新形式の保存が入った後は、legacy 単一 bookmark を通常フローでは更新しない。`videoBookmark` は移行専用の読み取り経路としてだけ残す。

### Restore

復元優先順位:

1. `playlistState` キー
2. 既存の単一 bookmark (`VideoFileValidator.resolveBookmarkedURL()`)
3. 空 playlist

復元手順:

1. `playlistState` を decode
2. entry ごとに bookmark を URL に解決する
3. 解決できた item だけ `PlaylistItem` に戻す
4. `currentItemID` が残っていればそれを current にする
5. 無効なら先頭 item を current にする
6. 結果が空なら playlist なし状態に戻す

### Legacy Migration

`playlistState` がなければ、既存の単一 bookmark を 1-item playlist に変換する。その後、新形式で即保存する。これにより移行後は playlist 側だけを信頼できる。

## Auto-Rotation Flow

### Completion Semantics

「再生完了」は動画全体ではなく、その item の有効な再生区間を 1 周した時点とする。

- `useFullVideo == true`
  item 全体を 1 回再生したら完了
- `useFullVideo == false`
  `playbackTimeRange` を 1 回再生したら完了

playlist が 1 件でも末尾でも、完了時は `RotationEngine` の wrap に従って先頭へ戻る。

### Playback Token

`RotationEngine.PlaybackToken` を current playback 世代の識別子として使う。

`AppDelegate` は `applyCurrentPlaylistItem()` のたびに新 token を発行し、全 `WallpaperWindowController` に同じ token を渡す。

完了通知は必ず token 付きで返す。古い item 由来の通知や、複数画面で遅れて届いた通知は token mismatch で無視する。

### WallpaperWindowController

追加責務:

- current playback context を保持する
- item 完了時に `onPlaybackFinished` を発火する

追加しない責務:

- 次 item を決める
- playlist を進める
- current item を保存する

実装方針:

- `AVPlayerItemDidPlayToEndTime` を監視する
- 現在の playback context に一致する event だけを受理する
- 受理したら `PlaybackCompletion` を callback で上位へ返す

`PlaybackCompletion` は少なくとも以下を含む。

- `token`
- `itemID` または現在 item を一意に識別できる値

### AppDelegate

追加責務:

- `PlaylistPersistence` の load / save 呼び出し
- current playback token の払い出し
- 完了通知から `PlaylistStore.next(using:)` を呼ぶ
- next item を全画面へ再適用する

主なフロー:

1. 起動時に `PlaylistPersistence` から復元
2. `applyCurrentPlaylistItem()` で token を発行
3. 各 `WallpaperWindowController` へ `item.url`, `item.playbackTimeRange`, `token` を渡す
4. どれか 1 画面から current token の完了通知を受ける
5. `playlistStore.next(using: token)` で current を進める
6. 再度 `applyCurrentPlaylistItem()` を呼ぶ
7. 保存対象の変更があれば persistence へ書き戻す

## Testing Strategy

### Branch 1: Persistence

新規:

- `PlaylistPersistenceTests`

確認内容:

- playlist 保存後に同じ items と `currentItemID` が復元される
- invalid bookmark を含む item は復元時に除外される
- invalid `currentItemID` は先頭 item に寄せられる
- legacy 単一 bookmark から 1-item playlist へ移行できる
- clear 後は空 state が復元される

既存:

- `PlaylistStoreTests` はメモリ上の state 変更だけを担当し続ける

### Branch 2: Auto-Rotation

拡張:

- `RotationEngineTests`

確認内容:

- current token の完了で next する
- stale token の完了は無視する
- 末尾から先頭へ wrap する
- single item でも current item が維持される

必要なら追加:

- `AppDelegate` または切り出した coordinator のテスト
- `WallpaperWindowController` の completion callback 発火条件テスト

`UserDefaults` を触る suite には `@Suite(.serialized)` を付ける。

## Risks

### Bookmark Decode Failure

ファイル移動や権限変化で bookmark 解決に失敗する可能性がある。復元では失敗 item を落とし、playlist が空になってもクラッシュしないようにする。

### Duplicate Completion

複数画面が同じ item を再生するため、完了通知は複数回来る。token で stale / duplicate completion を捨てる必要がある。

### Save Churn

編集 UI は開始秒 / 終了秒の変更が細かく発生する。件数が少ない前提なので全量保存でよいが、将来 entry 数が増えたら debounce を検討する。

## Rollout Order

1. `codex/playlist-persistence`
2. `codex/playlist-auto-rotation`

この順で積むことで、保存モデルを先に固定し、その上で再生完了制御を安全に追加できる。
