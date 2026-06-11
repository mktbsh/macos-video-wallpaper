# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい
4. 調査で完了扱いと現行コードのズレが見つかった項目は、Audit follow-up として再オープンする

---

## Audit follow-up: 2026-06-10 コードベース調査

### P1: 機能・再生ライフサイクル

- [ ] `StatusMenuController` に playlist 操作用の production menu を接続する（Add Videos / Edit Playlist / Next / Previous / Clear / summary）
- [ ] `AppDelegate` に `PlaybackSession` を持たせ、`playlistStore.currentItem` を `itemID` / `token` 付きで全 controller へ適用する
- [ ] 再生完了 callback で `PlaybackSession.consume(...)` を呼び、playlist advance / persist / UI reload / 次 item 適用までつなぐ
- [ ] playlist menu action と自動ローテーションの AppDelegate integration test を追加する（`Support/InMemoryDisplayWallpaperStore` / `Support/FakeWallpaperWindowController` が利用可能になった）
- [ ] pending seek completion が pause / hide / battery policy を破って `play()` しないよう、desired playback state と seek pending state を分離する
- [x] `seek` が `finished == false` で戻ったときも `isPlaybackStartPending` を解除し、次の `resumePlayback()` で復帰できるようにする
- [ ] occlusion notification では `isWindowOrderedFront` だけでなく `window.occlusionState.contains(.visible)` を見て、非表示なら pause する
- [ ] screen reconfiguration で surviving controller の window frame / content bounds / layer bounds を更新する API を追加する
- [x] runtime 用 display identity を `CGDirectDisplayID` ベースにし、同型 display / serial 0 の重複を正しく区別する（全ディスプレイ同一動画への移行で controller roster を `CGDirectDisplayID` キーに変更。ADR 2026-06-12）

### P2: パフォーマンス・永続化

- [ ] `PlaylistPersistence.save(store:)` を metadata 保存と bookmark sync に分離し、current item / display name 変更で bookmark payload decode / encode を走らせない
- [x] bookmark payload の duplicate ID を検出し、`Dictionary(uniqueKeysWithValues:)` の trap ではなく fallback / clear / warning にする（`uniquingKeysWith` で先勝ちに変更）
- [x] `PlaylistStore` / `RotationEngine` の mutator は値が変わらない場合 `false` を返し、no-op save / reload を抑制する
- [x] `StatusMenuController.displayStates` は unchanged assignment を skip する
- [ ] dynamic display menu item を `DisplayIdentifier` ごとに保持し、表示状態の更新は `title` / `state` / `isEnabled` / `isHidden` の差分適用にする
- [ ] `updateDisplayStates()` で毎回 bookmark resolve しないよう、表示用 state の更新契機と bookmark 解決を分ける
- [ ] clean checkout の `make build` が CI と同じ `BuildInfo.swift` stub / generation 前提で通るようにする

### P3: UI/UX・アクセシビリティ

- [ ] Playlist editor の range 入力は keystroke ごとではなく submit / focus loss / debounce で commit する
- [ ] Playlist editor の秒数 parse は表示と同じ `NumberFormatter` に寄せ、ローカライズされた小数区切りと invalid input の validation message を扱う
- [ ] Playlist editor sidebar に drag reorder / Finder drop import / row context menu / Delete shortcut を追加する
- [x] Playlist editor window に `minSize` と `setFrameAutosaveName(...)` を設定する
- [x] status item の normal / error state に応じた accessibility label / value / tooltip を追加する
- [ ] playlist current item の play icon は row accessibility label に状態を含めるか、装飾として hidden にする
- [ ] よく使う playlist 操作に menu command / keyboard shortcut を追加する

### Test / 設定 debt

- [ ] `make test` の test host bootstrapping 前 SIGKILL を切り分ける
- [ ] isolated DerivedData 実行で落ちた `AppDelegateScreenLifecycleTests/setup_pauses_playback_when_power_saving_mode_is_always` の状態漏れを調査する
- [x] `ProjectConfigurationTests` は生成済み entitlements だけでなく source of truth の `project.yml` を検証する
- [ ] UserDefaults を触る lifecycle / settings tests は suite-scoped defaults へ寄せられるか確認する

---

## Feature: App Store リリース準備 (#32)

- [ ] Step 2 は issue [#39](https://github.com/mktbsh/macos-video-wallpaper/issues/39) で進める
- [ ] Step 3 は issue [#40](https://github.com/mktbsh/macos-video-wallpaper/issues/40) で進める

---

## Backlog（検討中）

- [ ] 時間帯連動（朝・昼・夜で動画を自動切り替え）
