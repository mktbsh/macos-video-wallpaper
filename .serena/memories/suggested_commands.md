# Suggested Commands

## Build & Run
```bash
make run       # xcodegen + clean build → install to /Applications → launch
make build     # xcodegen + clean build only
make install   # xcodegen + build + install to /Applications (stop if running)
make uninstall # stop app + remove from /Applications
make dock      # add to Dock (run after make install)
```

## Project Generation
```bash
xcodegen generate   # regenerate .xcodeproj from project.yml
                    # REQUIRED when adding new .swift files
                    # (make build/run call this automatically)
```

## Testing
```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
```

## Git
```bash
git status
git log --oneline
git diff
```
Branch naming: `feature/xxx`, `fix/xxx`
Workflow: commit → push → PR to main

## macOS Utilities
```bash
pgrep -x VideoWallpaper    # check if app is running
pkill -x VideoWallpaper    # stop the app
open /Applications/VideoWallpaper.app
```
