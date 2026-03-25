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

## 利用者向け

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

### 備考

- バンドル ID は `com.local.VideoWallpaper` に設定されています。変更する場合は `project.yml` を編集してください。
- `project.yml` を変更した後は `xcodegen generate` を再実行して Xcode プロジェクトを再生成してください。

---

## ライセンス

[MIT](../../LICENSE)
