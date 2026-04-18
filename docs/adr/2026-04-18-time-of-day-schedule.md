---
title: 時間帯連動スケジュール機能 設計ドキュメント
date: 2026-04-18
status: approved
---

# 時間帯連動スケジュール機能

朝・昼・夜の3スロットで異なるプレイリストを自動切り替えする機能。

## 概要

- スロット数: 固定3（morning / afternoon / night）
- 各スロットに独立した `PlaylistStore`（ローテーション継続）
- 境界時刻はユーザーが設定可能（デフォルト: 朝6時・昼12時・夜18時）
- 1分ごとのタイマーと sleep 復帰で自動切り替え

---

## データモデル

### `TimeSlot`

```swift
enum TimeSlot: String, CaseIterable {
    case morning, afternoon, night
    var label: String  // ローカライズ済み表示名
}
```

### `ScheduleConfig`

```swift
struct ScheduleConfig: Codable, Equatable {
    var morningStart: Int    // 0-23
    var afternoonStart: Int
    var nightStart: Int

    static let `default` = ScheduleConfig(morningStart: 6, afternoonStart: 12, nightStart: 18)

    func currentSlot(at hour: Int) -> TimeSlot
}
```

境界は「その時刻から次の境界まで」で判定。例: `morningStart=6` なら 6:00〜11:59 が morning。

### `ScheduledPlaylistStore`

```swift
struct ScheduledPlaylistStore {
    var config: ScheduleConfig
    private var stores: [TimeSlot: PlaylistStore]

    var currentSlot: TimeSlot
    var activeStore: PlaylistStore

    func store(for slot: TimeSlot) -> PlaylistStore
    mutating func update(store: PlaylistStore, for slot: TimeSlot)
    mutating func activateSlot(for hour: Int)  // currentSlot を更新
}
```

既存の `PlaylistStore` / `RotationEngine` はそのまま再利用。`ScheduledPlaylistStore` はそれらの集約のみ担う。

---

## 永続化

`PlaylistPersistence` を拡張し、スロットごとに独立したキーで保存する。

```
playlist.metadata.morning   → morning スロットの PlaylistStore metadata
playlist.bookmarks.morning  → morning スロットの bookmark payload
playlist.metadata.afternoon → ...
playlist.bookmarks.afternoon
playlist.metadata.night
playlist.bookmarks.night
schedule.config             → ScheduleConfig (JSON)
```

既存の `playlist.metadata` / `playlist.bookmarks` キーは初回ロード時に morning スロットへ migration し、旧キーは削除する。

---

## AppDelegate 統合

`playlistStore: PlaylistStore` を `scheduledStore: ScheduledPlaylistStore` に置き換える。

### 起動時

1. `ScheduledPlaylistStore` をロード
2. 現在時刻でスロットを決定 → `scheduledStore.activateSlot(for: currentHour)`
3. `activeStore` の `currentItem` で再生開始

### スロット監視

```swift
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.checkAndApplySlotIfNeeded()
}
```

- 前回スロットと比較し、変化があれば `activeStore` を切り替えて再生を再始動
- `systemDidWake` でも同じチェックを実行（スリープ復帰対応）

### 切り替え時

1. 現在再生を停止
2. `scheduledStore.activateSlot(for: currentHour)`
3. 新 `activeStore` のプレイリストが空なら全ウィンドウに `clearVideo()` を呼んで終了
4. 空でなければ `activeStore.beginPlayback()` → 全ウィンドウに `load()` を流す（既存の再生適用パスを流用）

### `clockProvider` injection

テスト可能にするため、現在時刻の取得を inject 可能にする。

```swift
private let clockProvider: () -> Date
init(..., clockProvider: @escaping () -> Date = { Date() })
```

---

## UI（プレイリストエディタ拡張）

`PlaylistEditorWindowController` にセグメントコントロールと境界時刻フィールドを追加。

### レイアウト（上から）

```
[ 朝 | 昼 | 夜 ]                        ← NSSegmentedControl（現在スロットに ◉ マーク）
[ 朝: [06] 時  昼: [12] 時  夜: [18] 時 ]  ← NSTextField × 3
─────────────────────────────────────────
  既存のプレイリスト編集UI（選択スロットに連動）
```

### コールバック追加

```swift
var onScheduleConfigChanged: ((ScheduleConfig) -> Void)?
var onSlotPlaylistChanged: ((TimeSlot, PlaylistStore) -> Void)?
```

### 動作

- セグメント切り替え → 対応スロットの `PlaylistStore` をエディタにバインド
- 境界時刻フィールド変更 → `ScheduleConfig` 更新 → `onScheduleConfigChanged` 発火
- AppDelegate が通知を受け取り `scheduledStore.config` を更新・永続化

---

## テスト方針

### `ScheduleConfig`

- 各境界時刻エッジケース（ちょうど6時、5時59分など）で `currentSlot` が正しいスロットを返す
- `@Suite(.serialized)` 必須（UserDefaults 書き込みがある場合）

### `ScheduledPlaylistStore`

- スロット切り替えで `activeStore` が正しく入れ替わる
- 各スロットの `PlaylistStore` が独立して管理される

### AppDelegate 統合テスト

- `clockProvider` をフェイクにしてスロット境界をまたいだタイマー発火をシミュレート
- 新スロットのプレイリストが全ウィンドウに適用されるか検証

### プレイリストエディタ

- セグメント切り替えで対応スロットのデータがバインドされる
- 境界時刻変更で `onScheduleConfigChanged` が正しい値で呼ばれる

---

## 実装順序（推奨）

1. `TimeSlot` / `ScheduleConfig` / `ScheduledPlaylistStore` の追加（テスト先行）
2. `PlaylistPersistence` の拡張と migration
3. `AppDelegate` のスロット監視・切り替えロジック
4. `PlaylistEditorWindowController` のUI拡張
5. ローカライズ文字列追加（en / ja）
