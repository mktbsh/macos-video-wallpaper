# VideoWallpaper Project Overview

## Purpose
macOS menubar app that plays video files as desktop wallpaper. Runs as LSUIElement (no Dock icon). Supports multiple displays, playlists, brightness control, and power-saving mode.

## Tech Stack
- Swift 6.0 (strict concurrency)
- macOS 14.0+ deployment target
- AVFoundation (video playback)
- Cocoa / AppKit (UI)
- XcodeGen (project file generation from project.yml)
- Swift Testing framework (unit tests)
- App Sandbox enabled

## Architecture
```
AppDelegate
├── StatusMenuController   # menubar UI + callback definitions
└── [WallpaperWindowController] × screen count
    ├── AVQueuePlayer + AVPlayerLooper   # looping playback
    ├── AVPlayerLayer                    # video rendering
    └── dimLayer (CALayer)               # brightness overlay
```

- AppDelegate manages all windows in an array, propagates via callbacks
- UI actions: StatusMenuController callbacks (onXxxChanged) → AppDelegate → all windows
- `@MainActor` on all UI classes; async work wrapped in `Task { }`

## Key Source Files
- `Sources/AppDelegate.swift` - app entry, window management, notification handling
- `Sources/WallpaperWindowController.swift` - single-screen wallpaper window
- `Sources/StatusMenuController.swift` - menubar UI
- `Sources/DimLevel.swift` - brightness adjustment enum
- `Sources/PowerSavingMode.swift` - power-saving mode enum
- `Sources/VideoGravity.swift` - display mode enum (Cover/Contain/Fill)
- `Sources/VideoFileValidator.swift` - file validation + security-scope bookmarks
- `Sources/PlaylistModels.swift` - playlist data models
- `Sources/RotationEngine.swift` - playlist rotation logic
- `Sources/PlaybackDriver.swift` - playback orchestration
- `Sources/PlaylistEditorWindowController.swift` - playlist editor UI
- `Sources/BuildInfo.swift` - build timestamp (auto-generated, gitignored)
- `project.yml` - XcodeGen config
