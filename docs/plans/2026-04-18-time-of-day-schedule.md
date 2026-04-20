# Time-of-Day Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 朝・昼・夜の3スロットで異なるプレイリストを自動切り替えするスケジュール機能を実装する。

**Architecture:** `ScheduledPlaylistStore` が3つの `PlaylistStore`（スロットごと）と `ScheduleConfig`（境界時刻）を保持し、`AppDelegate` が1分タイマーと sleep 復帰でスロットを切り替える。`PlaylistEditorWindowController` にセグメントコントロールと境界時刻フィールドを追加し、スロットごとにプレイリストを編集できるようにする。

**Tech Stack:** Swift 6.0, macOS 14+, AppKit, SwiftUI (PlaylistEditor), Swift Testing

---

## ファイルマップ

### 新規作成
| ファイル | 役割 |
|--------|------|
| `Sources/TimeSlot.swift` | 朝/昼/夜 enum |
| `Sources/ScheduleConfig.swift` | 境界時刻設定 struct |
| `Sources/ScheduledPlaylistStore.swift` | 3スロット集約 struct |
| `Tests/VideoWallpaperTests/TimeSlotTests.swift` | TimeSlot テスト |
| `Tests/VideoWallpaperTests/ScheduleConfigTests.swift` | ScheduleConfig テスト |
| `Tests/VideoWallpaperTests/ScheduledPlaylistStoreTests.swift` | ScheduledPlaylistStore テスト |
| `Tests/VideoWallpaperTests/ScheduledPlaylistPersistenceTests.swift` | スロット別永続化テスト |
| `Tests/VideoWallpaperTests/AppDelegateScheduleTests.swift` | スロット切り替えテスト |
| `Tests/VideoWallpaperTests/AppDelegateTestHelpers.swift` | FakeWallpaperWindowController（共有） |

### 変更
| ファイル | 変更内容 |
|--------|--------|
| `Sources/PlaylistPersistence.swift` | スロット別 save/load、migration、config 永続化 |
| `Sources/AppDelegate.swift` | `scheduledStore` 置き換え、タイマー、rotation wire-up |
| `Sources/PlaylistEditorWindowController.swift` | スロット picker + 境界時刻 UI |
| `Sources/Localizable.xcstrings` | schedule.* 文字列追加 |
| `Tests/VideoWallpaperTests/AppDelegateScreenLifecycleTests.swift` | FakeWallpaperWindowController を共有 helper へ移動 |

---

## Task 1: TimeSlot enum

**Files:**
- Create: `Sources/TimeSlot.swift`
- Create: `Tests/VideoWallpaperTests/TimeSlotTests.swift`

- [ ] **Step 1: テストファイルを作成（新規 Swift ファイル追加前）**

```swift
// Tests/VideoWallpaperTests/TimeSlotTests.swift
import Testing
@testable import VideoWallpaper

@Suite struct TimeSlotTests {

    @Test func allCases_has_three_elements() {
        #expect(TimeSlot.allCases.count == 3)
    }

    @Test func rawValues_are_stable() {
        #expect(TimeSlot.morning.rawValue == "morning")
        #expect(TimeSlot.afternoon.rawValue == "afternoon")
        #expect(TimeSlot.night.rawValue == "night")
    }

    @Test func codable_roundtrip() throws {
        for slot in TimeSlot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(TimeSlot.self, from: data)
            #expect(decoded == slot)
        }
    }
}
```

- [ ] **Step 2: xcodegen + ビルド確認（コンパイルエラーが出ることを確認）**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `error: cannot find type 'TimeSlot'`

- [ ] **Step 3: TimeSlot を実装**

```swift
// Sources/TimeSlot.swift
import Foundation

enum TimeSlot: String, CaseIterable, Codable {
    case morning
    case afternoon
    case night

    var label: String {
        switch self {
        case .morning:   return String(localized: "schedule.slot.morning")
        case .afternoon: return String(localized: "schedule.slot.afternoon")
        case .night:     return String(localized: "schedule.slot.night")
        }
    }
}
```

- [ ] **Step 4: xcodegen → テスト実行**

```bash
xcodegen generate
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: `TimeSlotTests` の全テストが passed

- [ ] **Step 5: コミット**

```bash
git add Sources/TimeSlot.swift Tests/VideoWallpaperTests/TimeSlotTests.swift VideoWallpaper.xcodeproj/project.pbxproj
git commit -m "feat: add TimeSlot enum for schedule feature"
```

---

## Task 2: ScheduleConfig

**Files:**
- Create: `Sources/ScheduleConfig.swift`
- Create: `Tests/VideoWallpaperTests/ScheduleConfigTests.swift`

- [ ] **Step 1: テストファイルを作成**

```swift
// Tests/VideoWallpaperTests/ScheduleConfigTests.swift
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct ScheduleConfigTests {

    private let config = ScheduleConfig.default  // morning=6, afternoon=12, night=18

    // MARK: - currentSlot(at:)

    @Test func hour_before_morning_returns_night() {
        #expect(config.currentSlot(at: 0) == .night)
        #expect(config.currentSlot(at: 5) == .night)
    }

    @Test func morning_boundary_returns_morning() {
        #expect(config.currentSlot(at: 6) == .morning)
    }

    @Test func hour_in_morning_returns_morning() {
        #expect(config.currentSlot(at: 11) == .morning)
    }

    @Test func afternoon_boundary_returns_afternoon() {
        #expect(config.currentSlot(at: 12) == .afternoon)
    }

    @Test func hour_in_afternoon_returns_afternoon() {
        #expect(config.currentSlot(at: 17) == .afternoon)
    }

    @Test func night_boundary_returns_night() {
        #expect(config.currentSlot(at: 18) == .night)
    }

    @Test func hour_at_end_of_night_returns_night() {
        #expect(config.currentSlot(at: 23) == .night)
    }

    // MARK: - Codable

    @Test func codable_roundtrip() throws {
        let original = ScheduleConfig(morningStart: 7, afternoonStart: 13, nightStart: 21)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 2: xcodegen + コンパイルエラー確認**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `error: cannot find type 'ScheduleConfig'`

- [ ] **Step 3: ScheduleConfig を実装**

```swift
// Sources/ScheduleConfig.swift
import Foundation

struct ScheduleConfig: Codable, Equatable {
    var morningStart: Int    // 0-23
    var afternoonStart: Int
    var nightStart: Int

    static let `default` = ScheduleConfig(morningStart: 6, afternoonStart: 12, nightStart: 18)
    static let storageKey = "schedule.config"

    /// 時刻（hour: 0-23）からスロットを返す。
    /// morning: [morningStart, afternoonStart)
    /// afternoon: [afternoonStart, nightStart)
    /// night: [nightStart, 24) ∪ [0, morningStart)
    func currentSlot(at hour: Int) -> TimeSlot {
        if hour >= nightStart || hour < morningStart {
            return .night
        } else if hour >= afternoonStart {
            return .afternoon
        } else {
            return .morning
        }
    }
}
```

- [ ] **Step 4: xcodegen → テスト実行**

```bash
xcodegen generate
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: `ScheduleConfigTests` の全テストが passed

- [ ] **Step 5: コミット**

```bash
git add Sources/ScheduleConfig.swift Tests/VideoWallpaperTests/ScheduleConfigTests.swift VideoWallpaper.xcodeproj/project.pbxproj
git commit -m "feat: add ScheduleConfig with currentSlot(at:) logic"
```

---

## Task 3: ScheduledPlaylistStore

**Files:**
- Create: `Sources/ScheduledPlaylistStore.swift`
- Create: `Tests/VideoWallpaperTests/ScheduledPlaylistStoreTests.swift`

- [ ] **Step 1: テストファイルを作成**

```swift
// Tests/VideoWallpaperTests/ScheduledPlaylistStoreTests.swift
import Foundation
import Testing
@testable import VideoWallpaper

@Suite struct ScheduledPlaylistStoreTests {

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name).mp4")
    }

    // MARK: - store(for:) / update(store:for:)

    @Test func store_for_slot_returns_empty_when_not_set() {
        let store = ScheduledPlaylistStore()
        #expect(store.store(for: .morning).items.isEmpty)
        #expect(store.store(for: .afternoon).items.isEmpty)
        #expect(store.store(for: .night).items.isEmpty)
    }

    @Test func update_and_retrieve_store_for_slot() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        var playlist = PlaylistStore()
        playlist.add(urls: [makeURL("a")])
        scheduled.update(store: playlist, for: .morning)
        #expect(scheduled.store(for: .morning).items.count == 1)
    }

    @Test func slots_are_independent() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        var morning = PlaylistStore()
        morning.add(urls: [makeURL("m")])
        var afternoon = PlaylistStore()
        afternoon.add(urls: [makeURL("a1"), makeURL("a2")])

        scheduled.update(store: morning, for: .morning)
        scheduled.update(store: afternoon, for: .afternoon)

        #expect(scheduled.store(for: .morning).items.count == 1)
        #expect(scheduled.store(for: .afternoon).items.count == 2)
        #expect(scheduled.store(for: .night).items.isEmpty)
    }

    // MARK: - activeStore

    @Test func activeStore_reflects_current_slot() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        var playlist = PlaylistStore()
        playlist.add(urls: [makeURL("m")])
        scheduled.update(store: playlist, for: .morning)
        #expect(scheduled.activeStore.items.count == 1)
    }

    @Test func activeStore_setter_updates_current_slot_store() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .night)
        var playlist = PlaylistStore()
        playlist.add(urls: [makeURL("n")])
        scheduled.activeStore = playlist
        #expect(scheduled.store(for: .night).items.count == 1)
        #expect(scheduled.store(for: .morning).items.isEmpty)
    }

    // MARK: - activateSlot(for:)

    @Test func activateSlot_switches_to_expected_slot() {
        // default config: morning=6, afternoon=12, night=18
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        scheduled.activateSlot(for: 14)  // 14:00 → afternoon
        #expect(scheduled.currentSlot == .afternoon)
    }

    @Test func activateSlot_changes_active_store() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        var afternoon = PlaylistStore()
        afternoon.add(urls: [makeURL("a")])
        scheduled.update(store: afternoon, for: .afternoon)

        scheduled.activateSlot(for: 14)

        #expect(scheduled.activeStore.items.count == 1)
    }

    @Test func activateSlot_at_night_boundary() {
        var scheduled = ScheduledPlaylistStore(currentSlot: .afternoon)
        scheduled.activateSlot(for: 18)
        #expect(scheduled.currentSlot == .night)
    }
}
```

- [ ] **Step 2: xcodegen + コンパイルエラー確認**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `error: cannot find type 'ScheduledPlaylistStore'`

- [ ] **Step 3: ScheduledPlaylistStore を実装**

```swift
// Sources/ScheduledPlaylistStore.swift
import Foundation

struct ScheduledPlaylistStore {
    var config: ScheduleConfig
    private var stores: [TimeSlot: PlaylistStore]
    private(set) var currentSlot: TimeSlot

    init(
        config: ScheduleConfig = .default,
        stores: [TimeSlot: PlaylistStore] = [:],
        currentSlot: TimeSlot = .morning
    ) {
        self.config = config
        self.stores = stores
        self.currentSlot = currentSlot
    }

    var activeStore: PlaylistStore {
        get { stores[currentSlot] ?? PlaylistStore() }
        set { stores[currentSlot] = newValue }
    }

    func store(for slot: TimeSlot) -> PlaylistStore {
        stores[slot] ?? PlaylistStore()
    }

    mutating func update(store: PlaylistStore, for slot: TimeSlot) {
        stores[slot] = store
    }

    mutating func activateSlot(for hour: Int) {
        currentSlot = config.currentSlot(at: hour)
    }
}
```

- [ ] **Step 4: xcodegen → テスト実行**

```bash
xcodegen generate
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: `ScheduledPlaylistStoreTests` の全テストが passed

- [ ] **Step 5: コミット**

```bash
git add Sources/ScheduledPlaylistStore.swift Tests/VideoWallpaperTests/ScheduledPlaylistStoreTests.swift VideoWallpaper.xcodeproj/project.pbxproj
git commit -m "feat: add ScheduledPlaylistStore wrapping per-slot PlaylistStores"
```

---

## Task 4: PlaylistPersistence スロット別永続化

**Files:**
- Modify: `Sources/PlaylistPersistence.swift`
- Create: `Tests/VideoWallpaperTests/ScheduledPlaylistPersistenceTests.swift`

- [ ] **Step 1: テストファイルを作成**

```swift
// Tests/VideoWallpaperTests/ScheduledPlaylistPersistenceTests.swift
import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct ScheduledPlaylistPersistenceTests {

    private let suiteName = "com.test.ScheduledPlaylistPersistence"
    private var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }
    private var persistence: PlaylistPersistence { PlaylistPersistence(defaults: defaults) }

    private func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - スロット別キー

    @Test func storageKey_for_slot_includes_slot_name() {
        #expect(PlaylistPersistence.storageKey(for: .morning) == "playlist.metadata.morning")
        #expect(PlaylistPersistence.storageKey(for: .afternoon) == "playlist.metadata.afternoon")
        #expect(PlaylistPersistence.storageKey(for: .night) == "playlist.metadata.night")
    }

    @Test func bookmarkKey_for_slot_includes_slot_name() {
        #expect(PlaylistPersistence.bookmarkKey(for: .morning) == "playlist.bookmarks.morning")
    }

    // MARK: - loadScheduled: 空の場合

    @Test func loadScheduled_returns_empty_stores_when_nothing_persisted() {
        cleanup()
        defer { cleanup() }
        let scheduled = persistence.loadScheduled()
        for slot in TimeSlot.allCases {
            #expect(scheduled.store(for: slot).items.isEmpty)
        }
    }

    // MARK: - save(config:) / loadConfig()

    @Test func save_and_load_config_roundtrip() {
        cleanup()
        defer { cleanup() }
        let config = ScheduleConfig(morningStart: 7, afternoonStart: 13, nightStart: 20)
        persistence.save(config: config)
        #expect(persistence.loadConfig() == config)
    }

    @Test func loadConfig_returns_default_when_nothing_persisted() {
        cleanup()
        defer { cleanup() }
        #expect(persistence.loadConfig() == .default)
    }

    // MARK: - migration

    @Test func loadScheduled_migrates_legacy_playlistState_to_morning() throws {
        cleanup()
        defer { cleanup() }

        // Seed legacy metadata (no items, no bookmarks = safe to migrate without sandbox)
        let legacyState = PersistedPlaylistState(entries: [], currentItemID: nil)
        let data = try JSONEncoder().encode(legacyState)
        defaults.set(data, forKey: PlaylistPersistence.storageKey)

        _ = persistence.loadScheduled()

        #expect(
            defaults.data(forKey: PlaylistPersistence.storageKey) == nil,
            "Legacy key must be removed after migration"
        )
        #expect(
            defaults.data(forKey: PlaylistPersistence.storageKey(for: .morning)) != nil,
            "Morning slot key must exist after migration"
        )
    }

    @Test func loadScheduled_skips_migration_when_morning_slot_exists() throws {
        cleanup()
        defer { cleanup() }

        // Set up both legacy and slot-specific keys
        let state = PersistedPlaylistState(entries: [], currentItemID: nil)
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: PlaylistPersistence.storageKey)
        defaults.set(data, forKey: PlaylistPersistence.storageKey(for: .morning))

        _ = persistence.loadScheduled()

        // Legacy key must NOT be removed (migration skipped)
        #expect(defaults.data(forKey: PlaylistPersistence.storageKey) != nil)
    }

    // MARK: - save(scheduled:) / saveSlot(_:for:)

    @Test func saveSlot_writes_metadata_key_for_slot() {
        cleanup()
        defer { cleanup() }
        let store = PlaylistStore()
        persistence.saveSlot(store, for: .afternoon)
        #expect(defaults.data(forKey: PlaylistPersistence.storageKey(for: .afternoon)) != nil)
        #expect(defaults.data(forKey: PlaylistPersistence.storageKey(for: .morning)) == nil)
    }

    @Test func save_scheduled_writes_all_slot_keys() {
        cleanup()
        defer { cleanup() }
        let scheduled = ScheduledPlaylistStore()
        persistence.save(scheduled: scheduled)
        for slot in TimeSlot.allCases {
            #expect(defaults.data(forKey: PlaylistPersistence.storageKey(for: slot)) != nil)
        }
    }

    @Test func save_scheduled_writes_config_key() {
        cleanup()
        defer { cleanup() }
        var scheduled = ScheduledPlaylistStore()
        scheduled.config = ScheduleConfig(morningStart: 8, afternoonStart: 14, nightStart: 20)
        persistence.save(scheduled: scheduled)
        #expect(persistence.loadConfig().morningStart == 8)
    }
}
```

- [ ] **Step 2: xcodegen + コンパイルエラー確認**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: コンパイルエラー（`storageKey(for:)` etc. が未定義）

- [ ] **Step 3: PlaylistPersistence を修正**

`Sources/PlaylistPersistence.swift` の `struct PlaylistPersistence {` ブロック内に以下を追加・修正する。

**追加するスタティックキー（既存の `storageKey`, `bookmarkStorageKey` の直下）:**
```swift
static func storageKey(for slot: TimeSlot) -> String { "playlist.metadata.\(slot.rawValue)" }
static func bookmarkKey(for slot: TimeSlot) -> String { "playlist.bookmarks.\(slot.rawValue)" }
static let scheduleConfigKey = "schedule.config"
```

**追加するパブリックメソッド（`clear()` の後に追加）:**
```swift
func saveSlot(_ store: PlaylistStore, for slot: TimeSlot) {
    saveStore(store, metadataKey: Self.storageKey(for: slot), bookmarkKey: Self.bookmarkKey(for: slot))
}

func save(scheduled: ScheduledPlaylistStore) {
    save(config: scheduled.config)
    for slot in TimeSlot.allCases {
        saveSlot(scheduled.store(for: slot), for: slot)
    }
}

func loadScheduled() -> ScheduledPlaylistStore {
    // migration: morning スロットが未作成で旧 playlistState があれば morning に移行
    if defaults.data(forKey: Self.storageKey(for: .morning)) == nil,
       defaults.data(forKey: Self.storageKey) != nil {
        let legacyStore = load()
        saveSlot(legacyStore, for: .morning)
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.bookmarkStorageKey)
    }

    var stores: [TimeSlot: PlaylistStore] = [:]
    for slot in TimeSlot.allCases {
        stores[slot] = loadSlot(slot)
    }
    return ScheduledPlaylistStore(config: loadConfig(), stores: stores, currentSlot: .morning)
}

func loadConfig() -> ScheduleConfig {
    guard let data = defaults.data(forKey: Self.scheduleConfigKey),
          let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data)
    else { return .default }
    return config
}

func save(config: ScheduleConfig) {
    guard let data = try? JSONEncoder().encode(config) else { return }
    defaults.set(data, forKey: Self.scheduleConfigKey)
}
```

**追加するプライベートメソッド（`loadLegacyStore()` の後に追加）:**
```swift
private func loadSlot(_ slot: TimeSlot) -> PlaylistStore {
    guard let data = defaults.data(forKey: Self.storageKey(for: slot)) else { return PlaylistStore() }
    guard let state = try? JSONDecoder().decode(PersistedPlaylistState.self, from: data) else {
        return PlaylistStore()
    }
    let bookmarks = decodedBookmarks(from: defaults.data(forKey: Self.bookmarkKey(for: slot))) ?? []
    return restorePlaylistStore(from: state, bookmarks: bookmarks)
}

private func saveStore(_ store: PlaylistStore, metadataKey: String, bookmarkKey: String) {
    let state = PersistedPlaylistState(store: store)
    guard let stateData = try? JSONEncoder().encode(state),
          let bmData = encodedBookmarks(for: store, bookmarkKey: bookmarkKey) else { return }
    defaults.set(stateData, forKey: metadataKey)
    persistBookmarks(bmData, key: bookmarkKey)
}

private func encodedBookmarks(for store: PlaylistStore, bookmarkKey: String) -> Data? {
    let bookmarks = try? resolvedBookmarks(for: store, bookmarkKey: bookmarkKey)
    guard let bookmarks else { return nil }
    guard !bookmarks.isEmpty else { return Data("[]".utf8) }
    return try? JSONEncoder().encode(bookmarks)
}

private func resolvedBookmarks(for store: PlaylistStore, bookmarkKey: String) throws -> [PersistedPlaylistBookmark] {
    let cached = Dictionary(
        uniqueKeysWithValues: (decodedBookmarks(from: defaults.data(forKey: bookmarkKey)) ?? []).map { ($0.id, $0) }
    )
    return try store.items.map { item in
        if let bm = cached[item.id], bm.matches(item) { return bm }
        return try PersistedPlaylistBookmark(item: item)
    }
}

private func persistBookmarks(_ bookmarkData: Data, key: String) {
    let existingData = defaults.data(forKey: key)
    guard existingData != bookmarkData else { return }
    if bookmarkData == Data("[]".utf8) {
        defaults.removeObject(forKey: key)
    } else {
        defaults.set(bookmarkData, forKey: key)
    }
}
```

**既存の `save(store:)` を修正**（`saveStore` ヘルパーを使うよう変更）:
```swift
func save(store: PlaylistStore) {
    saveStore(store, metadataKey: Self.storageKey, bookmarkKey: Self.bookmarkStorageKey)
    VideoFileValidator.clearBookmark(defaults: defaults)
}
```

**既存の `encodedBookmarks(for:)`, `resolvedBookmarks(for:)`, `persistBookmarksIfNeeded(_:)` を削除**し、新しいパラメータ付きバージョンを使用。`encodedBookmarks` の既存呼び出しは `saveStore` ヘルパーに統合済みのため不要。

- [ ] **Step 4: xcodegen → テスト実行**

```bash
xcodegen generate
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: `ScheduledPlaylistPersistenceTests` の全テストが passed、既存テストも passed

- [ ] **Step 5: コミット**

```bash
git add Sources/PlaylistPersistence.swift Tests/VideoWallpaperTests/ScheduledPlaylistPersistenceTests.swift VideoWallpaper.xcodeproj/project.pbxproj
git commit -m "feat: add slot-keyed persistence and migration to PlaylistPersistence"
```

---

## Task 5: AppDelegate スロット切り替え + rotation wire-up

**Files:**
- Create: `Tests/VideoWallpaperTests/AppDelegateTestHelpers.swift` (FakeWallpaperWindowController を共有化)
- Modify: `Tests/VideoWallpaperTests/AppDelegateScreenLifecycleTests.swift` (private class 削除)
- Modify: `Sources/AppDelegate.swift`
- Create: `Tests/VideoWallpaperTests/AppDelegateScheduleTests.swift`

- [ ] **Step 1: FakeWallpaperWindowController を共有ヘルパーへ移動**

`Tests/VideoWallpaperTests/AppDelegateTestHelpers.swift` を新規作成し、`AppDelegateScreenLifecycleTests.swift` にある private `FakeWallpaperWindowController` を移動する。

```swift
// Tests/VideoWallpaperTests/AppDelegateTestHelpers.swift
import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@MainActor
final class FakeWallpaperWindowController: WallpaperWindowControlling {

    var onVideoDropped: ((URL, DisplayIdentifier) -> Void)?
    var onPlaybackFinished: ((PlaybackCompletion) -> Void)?
    var onPlaybackFailed: ((DisplayIdentifier) -> Void)?

    private(set) var loadCallCount = 0
    private(set) var loadedURLs: [URL] = []
    private(set) var loadedTokens: [RotationEngine<PlaylistItem>.PlaybackToken?] = []
    private(set) var resumeCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearVideoCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var applyDimLevelCallCount = 0
    private(set) var applyVideoGravityCallCount = 0

    func load(
        videoURL url: URL,
        timeRange: CMTimeRange?,
        itemID: PlaylistItem.ID?,
        token: RotationEngine<PlaylistItem>.PlaybackToken?
    ) {
        loadCallCount += 1
        loadedURLs.append(url)
        loadedTokens.append(token)
    }

    func clearVideo() { clearVideoCallCount += 1 }
    func invalidate() { invalidateCallCount += 1 }
    func applyDimLevel(_ opacity: CGFloat) { applyDimLevelCallCount += 1 }
    func applyVideoGravity(_ gravity: VideoGravity) { applyVideoGravityCallCount += 1 }
    func pausePlayback() { pauseCallCount += 1 }
    func resumePlayback() { resumeCallCount += 1 }
}
```

`AppDelegateScreenLifecycleTests.swift` から `private final class FakeWallpaperWindowController` の定義（`@MainActor private final class FakeWallpaperWindowController: WallpaperWindowControlling { ... }` 全体）を削除する。

- [ ] **Step 2: テストファイルを作成**

```swift
// Tests/VideoWallpaperTests/AppDelegateScheduleTests.swift
import AppKit
import AVFoundation
import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) @MainActor
struct AppDelegateScheduleTests {

    private func makeScreen() throws -> NSScreen {
        try #require(NSScreen.screens.first)
    }

    // MARK: - スロット初期化

    @Test func applicationDidFinishLaunching_activates_correct_slot_from_clock() throws {
        let screen = try makeScreen()
        let controller = FakeWallpaperWindowController()

        // clockProvider が 14:00 を返す → afternoon スロット
        let clock = Date(timeIntervalSinceReferenceDate: 0)  // 2001-01-01 00:00 UTC = JST 09:00 (morning)
        // 正確にスロットを制御するため scheduledStore を直接渡す
        var scheduled = ScheduledPlaylistStore(
            config: ScheduleConfig(morningStart: 6, afternoonStart: 12, nightStart: 18)
        )
        var morning = PlaylistStore()
        morning.add(urls: [URL(fileURLWithPath: "/tmp/morning.mp4")])
        scheduled.update(store: morning, for: .morning)

        let delegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            scheduledStore: scheduled,
            isOnBatteryProvider: { false },
            clockProvider: { clock }
        )

        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        // morningStart=6, clockProvider は JST 09:00 → morning スロット
        // morning に items がある → load が呼ばれる
        #expect(controller.loadCallCount >= 1)
    }

    // MARK: - checkAndApplySlotIfNeeded

    @Test func checkAndApplySlotIfNeeded_does_nothing_when_slot_unchanged() throws {
        let screen = try makeScreen()
        let controller = FakeWallpaperWindowController()
        var scheduled = ScheduledPlaylistStore(currentSlot: .afternoon)
        var afternoon = PlaylistStore()
        afternoon.add(urls: [URL(fileURLWithPath: "/tmp/af.mp4")])
        scheduled.update(store: afternoon, for: .afternoon)

        // clockProvider → 14:00 → afternoon（変化なし）
        let afterNoonDate = makeDate(hour: 14)
        let delegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            scheduledStore: scheduled,
            isOnBatteryProvider: { false },
            clockProvider: { afterNoonDate }
        )
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        let loadAfterSetup = controller.loadCallCount

        delegate.checkAndApplySlotIfNeeded()

        #expect(controller.loadCallCount == loadAfterSetup)
    }

    @Test func checkAndApplySlotIfNeeded_switches_slot_and_loads_new_item() throws {
        let screen = try makeScreen()
        let controller = FakeWallpaperWindowController()
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        var night = PlaylistStore()
        night.add(urls: [URL(fileURLWithPath: "/tmp/night.mp4")])
        scheduled.update(store: night, for: .night)

        // clockProvider → 20:00 → night（morning から変化）
        let nightDate = makeDate(hour: 20)
        let delegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            scheduledStore: scheduled,
            isOnBatteryProvider: { false },
            clockProvider: { nightDate }
        )
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        let loadAfterSetup = controller.loadCallCount

        delegate.checkAndApplySlotIfNeeded()

        #expect(controller.loadCallCount > loadAfterSetup)
        #expect(controller.loadedURLs.last?.lastPathComponent == "night.mp4")
    }

    @Test func checkAndApplySlotIfNeeded_clears_video_when_new_slot_has_no_items() throws {
        let screen = try makeScreen()
        let controller = FakeWallpaperWindowController()
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        // night スロットは空

        let nightDate = makeDate(hour: 20)
        let delegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            scheduledStore: scheduled,
            isOnBatteryProvider: { false },
            clockProvider: { nightDate }
        )
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))
        let clearAfterSetup = controller.clearVideoCallCount

        delegate.checkAndApplySlotIfNeeded()

        #expect(controller.clearVideoCallCount > clearAfterSetup)
    }

    // MARK: - playback completion → rotation

    @Test func playback_completion_advances_playlist_and_loads_next_item() throws {
        let screen = try makeScreen()
        let controller = FakeWallpaperWindowController()

        let url1 = URL(fileURLWithPath: "/tmp/item1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/item2.mp4")
        var morning = PlaylistStore()
        morning.add(urls: [url1, url2])
        var scheduled = ScheduledPlaylistStore(currentSlot: .morning)
        scheduled.update(store: morning, for: .morning)

        let morningDate = makeDate(hour: 8)
        let delegate = AppDelegate(
            screenProvider: { [screen] },
            controllerFactory: { _ in controller },
            scheduledStore: scheduled,
            isOnBatteryProvider: { false },
            clockProvider: { morningDate }
        )
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        // 最初のトークンを取得して完了通知を発火
        guard let token = controller.loadedTokens.last else {
            Issue.record("No token loaded")
            return
        }
        let firstItemID = morning.currentItem!.id
        let completion = PlaybackCompletion(itemID: firstItemID, token: token!)
        controller.onPlaybackFinished?(completion)

        #expect(controller.loadedURLs.last?.lastPathComponent == "item2.mp4")
    }

    // MARK: - helper

    private func makeDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 18
        components.hour = hour
        components.minute = 0
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components) ?? Date()
    }
}
```

- [ ] **Step 3: xcodegen + コンパイルエラー確認**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `AppDelegate.init` のシグネチャ変更エラーなど

- [ ] **Step 4: AppDelegate を修正**

`Sources/AppDelegate.swift` に以下の変更を加える。

**プロパティ変更**（`private var playlistStore: PlaylistStore` を置き換え）:
```swift
// 削除:
// private var playlistStore: PlaylistStore

// 追加:
private var scheduledStore: ScheduledPlaylistStore
private var playbackSession = PlaybackSession()
private var slotCheckTimer: Timer?
private let clockProvider: () -> Date
```

**init シグネチャ変更**（`playlistStore:` パラメータを置き換え）:
```swift
init(
    screenProvider: @escaping () -> [NSScreen] = { NSScreen.screens },
    controllerFactory: @escaping (NSScreen) -> any WallpaperWindowControlling = { screen in
        WallpaperWindowController(screen: screen, videoURL: nil)
    },
    scheduledStore: ScheduledPlaylistStore? = nil,
    isOnBatteryProvider: @escaping () -> Bool = defaultIsOnBattery,
    clockProvider: @escaping () -> Date = { Date() }
) {
    self.clockProvider = clockProvider
    let persistence = PlaylistPersistence()
    var store = scheduledStore ?? persistence.loadScheduled()
    let hour = Calendar.current.component(.hour, from: clockProvider())
    store.activateSlot(for: hour)
    self.scheduledStore = store
    self.screenControllers = []
    self.screenProvider = screenProvider
    self.controllerFactory = controllerFactory
    self.isOnBatteryProvider = isOnBatteryProvider
}
```

**`applicationDidFinishLaunching` に追加**（`setupWallpaperWindows()` の前に）:
```swift
startSlotTimer()
applyActivePlaylistSlot()
```

**`setupWallpaperWindows` 内の `onPlaybackFinished` を変更**:
```swift
// 変更前:
// controller.onPlaybackFinished = { _ in }

// 変更後:
controller.onPlaybackFinished = { [weak self] completion in
    Task { @MainActor in
        self?.handlePlaybackCompletion(completion)
    }
}
```

**`systemDidWake` を変更**:
```swift
@objc private func systemDidWake() {
    checkAndApplySlotIfNeeded()
    applyBatteryPolicy()
}
```

**新規メソッドを追加**（`applyBatteryPolicy(to:)` の後に）:

```swift
private func startSlotTimer() {
    slotCheckTimer?.invalidate()
    slotCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.checkAndApplySlotIfNeeded()
        }
    }
}

// internal: テストから直接呼べるよう private にしない
func checkAndApplySlotIfNeeded() {
    let hour = Calendar.current.component(.hour, from: clockProvider())
    let expected = scheduledStore.config.currentSlot(at: hour)
    guard expected != scheduledStore.currentSlot else { return }
    scheduledStore.activateSlot(for: hour)
    playbackSession = PlaybackSession()
    applyActivePlaylistSlot()
    persistScheduledState()
}

private func applyActivePlaylistSlot() {
    playbackSession = PlaybackSession()
    applyCurrentPlaylistItem()
}

private func applyCurrentPlaylistItem() {
    var activeStore = scheduledStore.activeStore
    guard let request = playbackSession.beginPlayback(using: &activeStore) else {
        scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
        screenControllers.forEach { $0.controller.clearVideo() }
        reloadPlaylistUI()
        return
    }
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    screenControllers.forEach {
        $0.controller.load(
            videoURL: request.item.url,
            timeRange: request.item.playbackTimeRange,
            itemID: request.item.id,
            token: request.token
        )
    }
    reloadPlaylistUI()
}

private func handlePlaybackCompletion(_ completion: PlaybackCompletion) {
    var activeStore = scheduledStore.activeStore
    let advanced = playbackSession.consume(completion, using: &activeStore)
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    guard advanced else { return }
    applyCurrentPlaylistItem()
    persistScheduledState()
    reloadPlaylistUI()
}
```

**既存の `playlistStore` 参照をすべて `scheduledStore.activeStore` または対応するメソッドへ置き換え**:

```swift
// showPlaylistEditor()
func showPlaylistEditor() {
    let editor = playlistEditorWindowController ?? makePlaylistEditorWindowController()
    let active = scheduledStore.activeStore
    editor.reload(items: active.items, currentItemID: active.currentItem?.id)
    editor.reloadSchedule(
        slot: scheduledStore.currentSlot,
        config: scheduledStore.config,
        activeSlot: scheduledStore.currentSlot
    )
    editor.showEditor()
}

// reloadPlaylistUI()
func reloadPlaylistUI() {
    let active = scheduledStore.activeStore
    playlistEditorWindowController?.reload(
        items: active.items,
        currentItemID: active.currentItem?.id
    )
}

// persistPlaylistState() → persistScheduledState()
func persistScheduledState() {
    playlistPersistence.save(scheduled: scheduledStore)
}

// presentVideoOpenPanel()
func presentVideoOpenPanel() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [
        .mpeg4Movie,
        .quickTimeMovie,
        UTType(filenameExtension: "m4v") ?? .movie
    ]
    guard panel.runModal() == .OK else { return }
    let urls = panel.urls.filter { VideoFileValidator.isSupported(extension: $0.pathExtension) }
    guard !urls.isEmpty else { return }

    var activeStore = scheduledStore.activeStore
    activeStore.add(urls: urls)
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    persistScheduledState()
    reloadPlaylistUI()
}

// deletePlaylistItem(id:)
func deletePlaylistItem(id: PlaylistItem.ID) {
    var activeStore = scheduledStore.activeStore
    guard activeStore.delete(id: id) else { return }
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    persistScheduledState()
    reloadPlaylistUI()
}

// movePlaylistItem(id:by:)
func movePlaylistItem(id: PlaylistItem.ID, by offset: Int) {
    var activeStore = scheduledStore.activeStore
    guard activeStore.move(id: id, by: offset) else { return }
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    persistScheduledState()
    reloadPlaylistUI()
}

// setCurrentPlaylistItem(id:)
func setCurrentPlaylistItem(id: PlaylistItem.ID) {
    var activeStore = scheduledStore.activeStore
    guard activeStore.setCurrent(id: id) else { return }
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    persistScheduledState()
    playbackSession = PlaybackSession()
    applyCurrentPlaylistItem()
}

// updatePlaylistItem(id:playbackSensitive:mutation:)
func updatePlaylistItem(
    id: PlaylistItem.ID,
    playbackSensitive: Bool,
    mutation: (inout PlaylistStore) -> Bool
) {
    var activeStore = scheduledStore.activeStore
    guard mutation(&activeStore) else { return }
    scheduledStore.update(store: activeStore, for: scheduledStore.currentSlot)
    persistScheduledState()
    reloadPlaylistUI()
}
```

**AppDelegate に `editorSelectedSlot` プロパティを追加**（`playbackSession` の隣に）:
```swift
// 追加: エディタが現在表示しているスロット（再生中スロットとは独立）
private var editorSelectedSlot: TimeSlot = .morning
```

**`showPlaylistEditor()` を修正**（エディタ開閉時に `editorSelectedSlot` を同期）:
```swift
func showPlaylistEditor() {
    let editor = playlistEditorWindowController ?? makePlaylistEditorWindowController()
    editorSelectedSlot = scheduledStore.currentSlot
    let slotStore = scheduledStore.store(for: editorSelectedSlot)
    editor.reload(items: slotStore.items, currentItemID: slotStore.currentItem?.id)
    editor.reloadSchedule(
        slot: editorSelectedSlot,
        config: scheduledStore.config,
        activeSlot: scheduledStore.currentSlot
    )
    editor.showEditor()
}
```

**`reloadPlaylistUI()` を `reloadEditorIfNeeded()` に置き換え**:
```swift
// 削除: func reloadPlaylistUI()

// 追加:
private func reloadEditorIfNeeded() {
    let store = scheduledStore.store(for: editorSelectedSlot)
    playlistEditorWindowController?.reload(
        items: store.items,
        currentItemID: store.currentItem?.id
    )
}
```

**`applyCurrentPlaylistItem()` 内の `reloadPlaylistUI()` 呼び出しを `reloadEditorIfNeeded()` に変更**。同様に `handlePlaybackCompletion` 内も変更。

**全エディタコールバックを `editorSelectedSlot` に向ける**（`scheduledStore.activeStore` → `scheduledStore.store(for: editorSelectedSlot)`）:

```swift
// presentVideoOpenPanel()
var store = scheduledStore.store(for: editorSelectedSlot)
store.add(urls: urls)
scheduledStore.update(store: store, for: editorSelectedSlot)
persistScheduledState()
reloadEditorIfNeeded()

// deletePlaylistItem(id:)
var store = scheduledStore.store(for: editorSelectedSlot)
guard store.delete(id: id) else { return }
scheduledStore.update(store: store, for: editorSelectedSlot)
persistScheduledState()
reloadEditorIfNeeded()

// movePlaylistItem / updatePlaylistItem も同様

// setCurrentPlaylistItem(id:): エディタ選択スロット == 再生スロット のときだけ再生を再始動
func setCurrentPlaylistItem(id: PlaylistItem.ID) {
    var store = scheduledStore.store(for: editorSelectedSlot)
    guard store.setCurrent(id: id) else { return }
    scheduledStore.update(store: store, for: editorSelectedSlot)
    persistScheduledState()
    if editorSelectedSlot == scheduledStore.currentSlot {
        playbackSession = PlaybackSession()
        applyCurrentPlaylistItem()
    } else {
        reloadEditorIfNeeded()
    }
}
```

**`configure(editor:)` にスロット関連コールバックを追加**:
```swift
editor.onSlotChanged = { [weak self] slot in
    guard let self else { return }
    editorSelectedSlot = slot
    let store = scheduledStore.store(for: slot)
    playlistEditorWindowController?.reload(
        items: store.items,
        currentItemID: store.currentItem?.id
    )
}

editor.onScheduleConfigChanged = { [weak self] config in
    self?.scheduledStore.config = config
    self?.persistScheduledState()
}
```

- [ ] **Step 5: xcodegen → テスト実行**

```bash
xcodegen generate
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: `AppDelegateScheduleTests` の全テストが passed、既存テストも passed

- [ ] **Step 6: コミット**

```bash
git add Sources/AppDelegate.swift Sources/ScheduledPlaylistStore.swift \
    Tests/VideoWallpaperTests/AppDelegateTestHelpers.swift \
    Tests/VideoWallpaperTests/AppDelegateScheduleTests.swift \
    Tests/VideoWallpaperTests/AppDelegateScreenLifecycleTests.swift \
    VideoWallpaper.xcodeproj/project.pbxproj
git commit -m "feat: wire scheduled playlist store and slot timer into AppDelegate"
```

---

## Task 6: PlaylistEditorWindowController UI 拡張

**Files:**
- Modify: `Sources/PlaylistEditorWindowController.swift`

- [ ] **Step 1: PlaylistEditorState に schedule プロパティを追加**

`PlaylistEditorState` クラスに追加:
```swift
var selectedSlot: TimeSlot = .morning
var scheduleConfig: ScheduleConfig = .default
var activeSlot: TimeSlot = .morning
```

- [ ] **Step 2: PlaylistEditorActionBridge にコールバックを追加**

```swift
var onSlotChanged: ((TimeSlot) -> Void)?
var onScheduleConfigChanged: ((ScheduleConfig) -> Void)?
```

- [ ] **Step 3: PlaylistEditorWindowController にコールバック公開と reloadSchedule を追加**

```swift
var onSlotChanged: ((TimeSlot) -> Void)? {
    get { actions.onSlotChanged }
    set { actions.onSlotChanged = newValue }
}

var onScheduleConfigChanged: ((ScheduleConfig) -> Void)? {
    get { actions.onScheduleConfigChanged }
    set { actions.onScheduleConfigChanged = newValue }
}

func reloadSchedule(slot: TimeSlot, config: ScheduleConfig, activeSlot: TimeSlot) {
    state.selectedSlot = slot
    state.scheduleConfig = config
    state.activeSlot = activeSlot
}
```

- [ ] **Step 4: PlaylistEditorRootView にスロット picker + 境界時刻 UI を追加**

`PlaylistEditorRootView.body` を以下に変更:
```swift
var body: some View {
    VStack(spacing: 0) {
        scheduleHeader
        Divider()
        NavigationSplitView {
            PlaylistSidebarView(state: state, actions: actions)
                .navigationTitle(String(localized: "playlist_editor.title"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            actions.onAddVideos?()
                        } label: {
                            Label(
                                String(localized: "playlist_editor.add_videos"),
                                systemImage: "plus"
                            )
                        }
                    }
                }
        } detail: {
            if let selectedItem = state.selectedItem {
                PlaylistDetailView(state: state, item: selectedItem, actions: actions)
            } else {
                ContentUnavailableView(
                    String(localized: "playlist_editor.empty_state"),
                    systemImage: "music.note.list",
                    description: Text(String(localized: "playlist_editor.empty_state.description"))
                )
            }
        }
    }
}

private var scheduleHeader: some View {
    VStack(spacing: 6) {
        Picker("", selection: $state.selectedSlot) {
            ForEach(TimeSlot.allCases, id: \.self) { slot in
                Text(slotPickerLabel(slot)).tag(slot)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: state.selectedSlot) { _, newSlot in
            actions.onSlotChanged?(newSlot)
        }

        HStack(spacing: 20) {
            boundaryField(
                label: String(localized: "schedule.slot.morning"),
                value: $state.scheduleConfig.morningStart
            )
            boundaryField(
                label: String(localized: "schedule.slot.afternoon"),
                value: $state.scheduleConfig.afternoonStart
            )
            boundaryField(
                label: String(localized: "schedule.slot.night"),
                value: $state.scheduleConfig.nightStart
            )
        }
        .font(.callout)
        .onChange(of: state.scheduleConfig) { _, newConfig in
            actions.onScheduleConfigChanged?(newConfig)
        }
    }
    .padding([.horizontal, .top], 12)
    .padding(.bottom, 8)
}

private func slotPickerLabel(_ slot: TimeSlot) -> String {
    let active = slot == state.activeSlot ? " ●" : ""
    return slot.label + active
}

private func boundaryField(label: String, value: Binding<Int>) -> some View {
    HStack(spacing: 4) {
        Text(label + ":")
            .foregroundStyle(.secondary)
        Stepper(
            value: value,
            in: 0...23
        ) {
            Text(String(format: "%02d:00", value.wrappedValue))
                .monospacedDigit()
                .frame(width: 46, alignment: .leading)
        }
    }
}
```

- [ ] **Step 5: ビルド確認**

```bash
xcodegen generate
xcodebuild -scheme VideoWallpaper -configuration Release -derivedDataPath build -quiet build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 6: テスト実行**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: 全テスト passed

- [ ] **Step 7: コミット**

```bash
git add Sources/PlaylistEditorWindowController.swift
git commit -m "feat: add slot picker and boundary time UI to PlaylistEditorWindowController"
```

---

## Task 7: ローカライズ文字列追加

**Files:**
- Modify: `Sources/Localizable.xcstrings`

- [ ] **Step 1: 6キーを Localizable.xcstrings に追加**

`"strings"` オブジェクト内に以下を追加（既存キーのアルファベット順に挿入）:

```json
"schedule.slot.afternoon" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Afternoon"
      }
    },
    "ja" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "昼"
      }
    }
  }
},
"schedule.slot.morning" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Morning"
      }
    },
    "ja" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "朝"
      }
    }
  }
},
"schedule.slot.night" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Night"
      }
    },
    "ja" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "夜"
      }
    }
  }
},
```

- [ ] **Step 2: テスト実行（LocalizationCatalogTests を含む）**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```

Expected: 全テスト passed

- [ ] **Step 3: コミット**

```bash
git add Sources/Localizable.xcstrings
git commit -m "feat: add localization keys for time-of-day schedule slots"
```

---

## 最終確認

- [ ] **make build で Release ビルド成功**

```bash
make build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **全テスト passed**

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **todo.md の Backlog を更新**

`tasks/todo.md` の `## Backlog（検討中）` セクション内の「時間帯連動」を `[x]` に変更（またはセクションを削除）。

- [ ] **最終コミット**

```bash
git add tasks/todo.md
git commit -m "chore: mark time-of-day schedule as completed in backlog"
```
