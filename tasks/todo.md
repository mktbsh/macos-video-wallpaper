# VideoWallpaper TODO

## 運用ルール

1. タスクを追加するときはチェックボックス形式で書く
2. 完了したら `[x]` にする
3. セクションが全て完了したら、セクションごと削除してよい
4. 調査で完了扱いと現行コードのズレが見つかった項目は、Audit follow-up として再オープンする

---

## Audit follow-up: 2026-06-10 コードベース調査

> playlist / timeRange / seek / playlist-editor / per-display 関連の項目は
> ADR 2026-06-19（playlist サブシステムの全削除と GIF 対応）で不要化したため除去した。

### P1: 機能・再生ライフサイクル

- [ ] occlusion notification では `isWindowOrderedFront` だけでなく `window.occlusionState.contains(.visible)` を見て、非表示なら pause する
- [ ] screen reconfiguration で surviving controller の window frame / content bounds / layer bounds を更新する API を追加する
- [x] runtime 用 display identity を `CGDirectDisplayID` ベースにし、同型 display / serial 0 の重複を正しく区別する（ADR 2026-06-12）

### P2: パフォーマンス・永続化

- [ ] clean checkout の `make build` が CI と同じ `BuildInfo.swift` stub / generation 前提で通るようにする

### P3: UI/UX・アクセシビリティ

- [x] status item の normal / error state に応じた accessibility label / value / tooltip を追加する

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
- [ ] GIF の大きなフレーム展開を画面解像度へダウンサンプルする（v1 はメモリ制約なし。ADR 2026-06-19）
- [ ] Animated WebP / APNG 対応（GIF と同じ CALayer driver 経路で拡張可能）
