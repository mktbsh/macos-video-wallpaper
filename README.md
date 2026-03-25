# macos-video-wallpaper

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)](README.md)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)

A macOS app that plays a video file as your desktop wallpaper — looping seamlessly across all displays.

**Languages:** English | [日本語](docs/README/ja.md)

---

## Overview

- Plays MP4, MOV, or M4V files as a looping desktop wallpaper
- Works across all connected displays simultaneously
- Lives in the menu bar — no Dock icon
- Drag & drop a video onto the desktop to change it instantly
- Persists your video choice across reboots
- Optional login item to start automatically at login

**Requirements:** macOS 14.0 or later

---

## For Users

### How to use

1. Launch the app. A `▶⬜` icon appears in the menu bar.
2. Click the icon and choose **"動画を選択…"** to pick a video file (MP4 / MOV / M4V).
3. The video starts playing as your wallpaper immediately.
4. You can also drag and drop a video file directly onto the desktop.

To start the app automatically at login, enable **"ログイン時に起動"** from the menu.

---

## For Developers

### Requirements

- macOS 14.0+
- Xcode 26.3 (beta) — Swift 6
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Setup

```bash
git clone https://github.com/mktbsh/macos-video-wallpaper.git
cd macos-video-wallpaper
xcodegen generate
open VideoWallpaper.xcodeproj
```

### Build

```bash
# Debug
xcodebuild -scheme VideoWallpaper -configuration Debug build

# Release
xcodebuild -scheme VideoWallpaper -configuration Release build
```

### Test

```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
```

### Video Optimization

For the best performance and quality, use H.265 (HEVC) encoded videos at 1080p/30fps in SDR.
A conversion script is provided:

```bash
# Install ffmpeg (one-time)
brew install ffmpeg

# Convert any video to the optimal format
./scripts/optimize-video.sh ~/Downloads/your-video.mov

# Specify output path explicitly
./scripts/optimize-video.sh ~/Downloads/your-video.mov ~/Desktop/wallpaper.mp4
```

The script handles:
- Downscales to 1920×1080 (never upscales; letterboxes portrait/non-16:9 videos)
- Caps frame rate at 30fps
- Tone-maps HDR → SDR (BT.709) to prevent washed-out colors on SDR displays
- Strips audio (muted by default in the app anyway)
- Adds `faststart` flag for instant playback start

### Notes

- Bundle ID is set to `com.local.VideoWallpaper`. Change it in `project.yml` if needed.
- After editing `project.yml`, re-run `xcodegen generate` to regenerate the Xcode project.

---

## License

[MIT](LICENSE)
