## セッション継続

作業を再開するときは、まず以下を読むこと

- `tasks/todo.md` - 未着手タスクと進捗
- `tasks/knowledge.md` - 過去の失敗と学び

変更があった場合、上記を更新すること。

---

## チーム編成

セッション継続の情報をもとに、チーム編成（最大6人）を行い並列作業せよ

---

## ビルド・開発フロー

```bash
make run       # clean build → /Applications にインストール → 起動
make build     # clean build のみ
make uninstall # アプリ停止 + /Applications から削除
```

- **新しい `.swift` ファイルを追加したら必ず `xcodegen generate` を先に実行する**（`make build` / `make run` 経由なら自動）
- ブランチ命名: `feature/xxx`, `fix/xxx`
- 作業単位でコミット → push → main 向け PR

---

## テスト

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
```

- Swift Testing フレームワークを使用（`import Testing`, `#expect`, `#require`）
- **UserDefaults を読み書きするテストスイートには必ず `@Suite(.serialized)` を付ける**（並列実行による競合防止）
- TDD で進める: テスト → 失敗確認 → 実装 → グリーン確認

---

## アーキテクチャ

```
AppDelegate
├── StatusMenuController   # メニューバー UI・コールバック定義
└── [WallpaperWindowController] × 画面数
    ├── AVQueuePlayer + AVPlayerLooper   # ループ再生
    ├── AVPlayerLayer                    # 映像描画
    └── dimLayer (CALayer)               # 明るさオーバーレイ
```

- `AppDelegate` が全ウィンドウを配列で管理し、コールバック経由で伝播
- UI 操作は `StatusMenuController` のコールバック（`onXxxChanged`）→ `AppDelegate` → 全ウィンドウ へ流れる
- `@MainActor` を UI クラス全体に付与。非同期処理は `Task { }` で包む

---

## ファイル構成（主要ファイル）

| ファイル | 役割 |
|---------|------|
| `Sources/AppDelegate.swift` | アプリエントリ・ウィンドウ管理・通知ハンドリング |
| `Sources/WallpaperWindowController.swift` | 1画面分の壁紙ウィンドウ |
| `Sources/StatusMenuController.swift` | メニューバー UI |
| `Sources/DimLevel.swift` | 明るさ調整 enum |
| `Sources/PowerSavingMode.swift` | 低電力モード enum |
| `Sources/VideoGravity.swift` | 表示方法 enum (Cover/Contain/Fill) |
| `Sources/VideoFileValidator.swift` | ファイル検証・セキュリティスコープブックマーク |
| `Sources/BuildInfo.swift` | ビルド日時（preBuildScript で自動生成、gitignore済み） |
| `project.yml` | XcodeGen 設定（変更後は `xcodegen generate` を実行） |
