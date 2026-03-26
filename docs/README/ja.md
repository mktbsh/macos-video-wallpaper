# macos-video-wallpaper

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../../LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)](../../README.md)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)

動画ファイルをデスクトップ壁紙としてシームレスにループ再生する macOS アプリです。

**言語:** [English](../../README.md) | 日本語

---

## 概要

- MP4・MOV・M4V ファイルをループ再生してデスクトップ壁紙として表示
- 接続されている全ディスプレイに同時に表示
- メニューバーに常駐 — Dock アイコンなし
- デスクトップに動画ファイルをドラッグ＆ドロップしてすぐに変更可能
- 選択した動画は再起動後も維持される
- ログイン時の自動起動に対応

**動作環境:** macOS 14.0 以降

---

https://github.com/user-attachments/assets/d0ef9f03-bf2f-45d6-b94b-89fbc5c1f073

---

## 利用者向け

### ダウンロード & インストール

1. [Releases](https://github.com/mktbsh/macos-video-wallpaper/releases) ページから最新の `VideoWallpaper-vX.X.X.zip` をダウンロードします。
2. zip を展開し、`VideoWallpaper.app` を `/Applications` に移動します。
3. 隔離属性を削除します（Apple Developer ID で署名されていないため必要）：
   ```bash
   xattr -cr /Applications/VideoWallpaper.app
   ```
4. `/Applications` からアプリを起動します。

> **手順 3 が必要な理由:** Apple Developer ID 署名のないアプリはmacOS の Gatekeeper によってブロックされます。`xattr -cr` コマンドで隔離フラグを削除することで起動できるようになります。ソースコードを自分で確認できるオープンソースアプリでは安全な操作です。

### 使い方

1. アプリを起動すると、メニューバーに `▶⬜` アイコンが表示されます。
2. アイコンをクリックし、**「動画を選択…」** から動画ファイル（MP4 / MOV / M4V）を選択します。
3. 選択した動画がすぐに壁紙として再生されます。
4. デスクトップに直接ドラッグ＆ドロップしても変更できます。

ログイン時に自動起動するには、メニューの **「ログイン時に起動」** を有効にしてください。

---

## 開発者向け

### 必要な環境

- macOS 14.0 以降
- Xcode 26.3（ベータ版）— Swift 6
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint): `brew install swiftlint`

### 環境構築

```bash
git clone https://github.com/mktbsh/macos-video-wallpaper.git
cd macos-video-wallpaper
xcodegen generate
open VideoWallpaper.xcodeproj
```

### ビルド

```bash
# Debug
xcodebuild -scheme VideoWallpaper -configuration Debug build

# Release
xcodebuild -scheme VideoWallpaper -configuration Release build
```

### テスト

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
```

### 動画の最適化

最高のパフォーマンスと画質のために、H.265（HEVC）エンコード・1080p/30fps・SDR の動画を推奨します。
変換スクリプトを用意しています：

```bash
# ffmpeg のインストール（初回のみ）
brew install ffmpeg

# 動画を最適な形式に変換
./scripts/optimize-video.sh ~/Downloads/your-video.mov

# 出力先を明示的に指定する場合
./scripts/optimize-video.sh ~/Downloads/your-video.mov ~/Desktop/wallpaper.mp4
```

スクリプトの処理内容：
- 1920×1080 にダウンスケール（アップスケールなし。縦向き・非 16:9 動画はレターボックス）
- フレームレートを 30fps に制限
- HDR → SDR（BT.709）のトーンマッピング（SDR ディスプレイで色が飛ぶのを防止）
- 音声トラックを除去（アプリはデフォルトでミュート）
- `faststart` フラグを付与して即時再生に対応

### 備考

- バンドル ID は `com.local.VideoWallpaper` に設定されています。変更する場合は `project.yml` を編集してください。
- `project.yml` を変更した後は `xcodegen generate` を再実行して Xcode プロジェクトを再生成してください。

---

## ライセンス

[MIT](../../LICENSE)
