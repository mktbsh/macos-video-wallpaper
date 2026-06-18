# GIF 壁紙対応と playlist 撤去 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** アニメーション GIF を壁紙として選択・適用できるようにし、同時に到達不能な playlist サブシステムと timeRange/seek 機構を全削除する。

**Architecture:** `PlayerDriver` protocol を `AVPlayerLayer` 固定から `CALayer` ベースへ緩め、ループと失敗観測を driver の責務に統一する。動画は `AVQueuePlayer` + `AVPlayerLooper`、GIF は `CALayer` + `CAKeyframeAnimation` の無限ループで再生する。`WallpaperWindowController` は URL からメディア種別に応じた driver を生成し、`driver.layer` をサブレイヤーとして差し替える。再生完了観測・seek・PlaybackContext は撤去される。

**Tech Stack:** Swift 6.0, macOS 14+, AppKit, AVFoundation, ImageIO/CoreGraphics, QuartzCore, Swift Testing, XcodeGen

**Reference:** `docs/adr/2026-06-19-gif-support-and-playlist-removal.md`

---

## 実装上の重要な注意

- **Phase 1 / Phase 3 は独立しておりビルドが通る単位**。`xcodegen generate` を伴うのは新規 `.swift` 追加時のみ。
- **Phase 2（driver/controller/AppDelegate/playlist の協調変更）は中間状態でビルドが通らない**。Swift の型依存が相互に絡むため、Phase 2 内の全タスクを完了してから `make build` でビルド緑、`xcodebuild test` で全テスト緑を確認する。TDD は「新構造のテストを先に書き換える → 実装 → Phase 末でまとめて緑」の形を取る。
- コミットは Phase 単位（Phase 2 は協調変更のため 1 コミット）。
- 各 `make build` / `xcodebuild test` は `platform=macOS` で実行する。

## ファイルマップ

### 新規作成
| ファイル | 役割 |
|--------|------|
| `Sources/GIFDecoder.swift` | GIF フレーム delay → 累積 keyTimes / duration の純粋計算 + ImageIO デコード |
| `Sources/GIFPlayerDriver.swift` | `CALayer` + `CAKeyframeAnimation` で GIF を無限ループ再生する driver |
| `Sources/MediaPlayerDriverFactory.swift` | URL の拡張子から `AVPlayerDriver` / `GIFPlayerDriver` を生成する factory |
| `Tests/VideoWallpaperTests/GIFDecoderTests.swift` | keyTimes / duration / delay クランプの純粋ロジックテスト |
| `Tests/VideoWallpaperTests/MediaPlayerDriverFactoryTests.swift` | 拡張子 → driver 種別の選択テスト |

### 変更
| ファイル | 変更内容 |
|--------|--------|
| `Sources/VideoGravity.swift` | `caGravity: CALayerContentsGravity` を追加 |
| `Sources/VideoFileType.swift` | `gif` を許可拡張子・`UTType.gif` に追加。`isGIF(extension:)` 追加 |
| `Sources/PlaybackDriver.swift` | protocol を CALayer ベースへ刷新。`AVPlayerDriver` を `AVQueuePlayer`+`AVPlayerLooper` 化。`PlaybackObservationTarget`/`AVPlayerObservationTarget` 削除 |
| `Sources/WallpaperWindowController.swift` | driver factory 化・layer 差し替え・observer/seek/PlaybackContext 撤去・`load(videoURL:)` 単純化 |
| `Sources/AppDelegate.swift` | `WallpaperWindowControlling` 刷新。playlist コード全削除。`applyGlobalVideo` の load 呼び出し簡素化 |
| `Sources/Localizable.xcstrings` | `menu.playlist.*` / `playlist_editor.*` キー削除 |
| `Tests/.../WallpaperWindowTestHelpers.swift` | `FakePlayerDriver` を新 protocol へ書き換え。`FakePlaybackCompletionObserver` 等削除 |
| `Tests/.../Support/FakeWallpaperWindowController.swift` | `load(videoURL:)` 新シグネチャへ。`onPlaybackFinished` 削除 |
| `Tests/.../WallpaperWindowControllerTests.swift` | 新構造に書き換え |
| `Tests/.../WallpaperWindowControllerVisibilityTests.swift` | 新構造に書き換え |
| `Tests/.../PlaybackDriverTests.swift` | 新 protocol に書き換え |
| `Tests/.../PlaybackFailureTests.swift` | driver→callback の失敗通知に書き換え |
| `Tests/.../VideoFileTypeTests.swift` | gif 許可のテスト追加 |
| `Tests/.../VideoGravityTests.swift` | caGravity のテスト追加 |
| `Tests/.../LocalizationCatalogTests.swift` | playlist 文字列の期待削除 |

> `project.yml` は `sources: - Sources` のディレクトリ指定でファイルを自動収集するため、ファイルの追加/削除で `project.yml` の編集は不要。新規 `.swift` 追加・削除後は `xcodegen generate` を実行すれば反映される。

### 削除
| ファイル |
|--------|
| `Sources/PlaylistModels.swift` |
| `Sources/PlaybackSession.swift` |
| `Sources/RotationEngine.swift` |
| `Sources/PlaylistPersistence.swift` |
| `Sources/PlaylistEditorWindowController.swift` |
| `Sources/PlaybackCompletion.swift` |
| `Sources/PlaybackCompletionObserver.swift` |
| `Tests/.../PlaylistStoreTests.swift` |
| `Tests/.../PlaylistStoreMutationTests.swift` |
| `Tests/.../PlaylistPersistenceTests.swift` |
| `Tests/.../PlaybackSessionTests.swift` |
| `Tests/.../RotationEngineTests.swift` |
| `Tests/.../PlaylistEditorWindowControllerTests.swift` |

---

## Phase 1: 独立な追加（VideoGravity / VideoFileType）

### Task 1: VideoGravity に caGravity を追加

**Files:**
- Modify: `Sources/VideoGravity.swift`
- Test: `Tests/VideoWallpaperTests/VideoGravityTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`VideoGravityTests.swift` に追記:

```swift
import QuartzCore

@Test func caGravityMapsEachCase() {
    #expect(VideoGravity.fill.caGravity == .resizeAspectFill)
    #expect(VideoGravity.fit.caGravity == .resizeAspect)
    #expect(VideoGravity.stretch.caGravity == .resize)
}
```

- [ ] **Step 2: 失敗を確認**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/VideoGravityTests`
Expected: FAIL（`caGravity` 未定義でコンパイルエラー）

- [ ] **Step 3: 実装**

`Sources/VideoGravity.swift` の `avGravity` の直後に追加:

```swift
    var caGravity: CALayerContentsGravity {
        switch self {
        case .fill:    return .resizeAspectFill
        case .fit:     return .resizeAspect
        case .stretch: return .resize
        }
    }
```

ファイル冒頭 import に `import QuartzCore` を追加（`AVFoundation` が QuartzCore を含むが明示する）。

- [ ] **Step 4: テスト緑を確認**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/VideoGravityTests`
Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add Sources/VideoGravity.swift Tests/VideoWallpaperTests/VideoGravityTests.swift
git commit -m "feat: add CALayer contentsGravity mapping to VideoGravity"
```

### Task 2: VideoFileType に gif を追加

**Files:**
- Modify: `Sources/VideoFileType.swift`
- Test: `Tests/VideoWallpaperTests/VideoFileTypeTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`VideoFileTypeTests.swift` に追記:

```swift
@Test func gifIsSupported() {
    #expect(VideoFileType.isSupported(extension: "gif"))
    #expect(VideoFileType.isSupported(extension: "GIF"))
}

@Test func gifIsDetected() {
    #expect(VideoFileType.isGIF(extension: "gif"))
    #expect(VideoFileType.isGIF(extension: "GIF"))
    #expect(!VideoFileType.isGIF(extension: "mp4"))
}

@Test func allowedUTTypesIncludesGIF() {
    #expect(VideoFileType.allowedUTTypes.contains(.gif))
}
```

- [ ] **Step 2: 失敗を確認**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/VideoFileTypeTests`
Expected: FAIL（`isGIF` 未定義 / gif 非対応）

- [ ] **Step 3: 実装**

`Sources/VideoFileType.swift` を更新:

```swift
import Foundation
import UniformTypeIdentifiers

/// 対応メディア形式（動画 mp4 / mov / m4v、アニメーション GIF）の判定と UTType 一覧。
/// 純粋な値計算であり、永続化や seam を持たない。
enum VideoFileType {

    private static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "gif"]

    static let allowedUTTypes: [UTType] = [
        .mpeg4Movie,
        .quickTimeMovie,
        UTType(filenameExtension: "m4v") ?? .movie,
        .gif
    ]

    static func isSupported(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    static func isGIF(extension ext: String) -> Bool {
        ext.lowercased() == "gif"
    }
}
```

- [ ] **Step 4: テスト緑を確認**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/VideoFileTypeTests`
Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add Sources/VideoFileType.swift Tests/VideoWallpaperTests/VideoFileTypeTests.swift
git commit -m "feat: allow GIF in VideoFileType"
```

---

## Phase 2: driver/controller/AppDelegate 刷新 + playlist 撤去（協調変更・1 コミット）

> このフェーズは中間でビルドが通らない。全タスク完了後に `make build` と `xcodebuild test` で緑を確認してから 1 つのコミットにまとめる。

### Task 3: PlayerDriver protocol を CALayer ベースへ刷新

**Files:**
- Modify: `Sources/PlaybackDriver.swift`

- [ ] **Step 1: `Sources/PlaybackDriver.swift` を全面書き換え**

`AVPlayerObservationTarget` / `PlaybackObservationTarget` / 旧 protocol を削除し、以下に置き換える。`MainActorCompletionRelay` は GIF/動画とも失敗通知で使うため残す。

```swift
import AVFoundation
import Dispatch
import Foundation
import QuartzCore

@MainActor
protocol PlayerDriver: AnyObject {
    var layer: CALayer { get }
    var onPlaybackFailed: (() -> Void)? { get set }
    func load(url: URL)
    func play()
    func pause()
    func clear()
    func applyGravity(_ gravity: VideoGravity)
}

@MainActor
protocol PlayerDriverFactory {
    func makeDriver(for url: URL) -> PlayerDriver
}

enum MainActorCompletionRelay {
    static func run(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                operation()
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    operation()
                }
            }
        }
    }
}

@MainActor
final class AVPlayerDriver: PlayerDriver {
    let layer: AVPlayerLayer
    var onPlaybackFailed: (() -> Void)?

    private let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        layer = AVPlayerLayer(player: player)
    }

    func load(url: URL) {
        clear()
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            MainActorCompletionRelay.run {
                self?.onPlaybackFailed?()
            }
        }
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func clear() {
        looper?.disableLooping()
        looper = nil
        player.pause()
        player.removeAllItems()
        statusObservation?.invalidate()
        statusObservation = nil
    }

    func applyGravity(_ gravity: VideoGravity) {
        layer.videoGravity = gravity.avGravity
    }
}
```

> 注: `let layer: AVPlayerLayer` は protocol 要件 `var layer: CALayer { get }` を満たす（`AVPlayerLayer` は `CALayer` のサブクラス。Swift は get-only プロパティの共変リファインメントを許容）。

（このタスク単独ではビルドしない。Phase 2 末でまとめて確認する）

### Task 4: AVPlayerDriverFactory を削除し MediaPlayerDriverFactory を新設

**Files:**
- Create: `Sources/MediaPlayerDriverFactory.swift`
- Test: `Tests/VideoWallpaperTests/MediaPlayerDriverFactoryTests.swift`

- [ ] **Step 1: テストを書く**

`MediaPlayerDriverFactoryTests.swift` を新規作成:

```swift
import Testing
@testable import VideoWallpaper

@MainActor
struct MediaPlayerDriverFactoryTests {
    @Test func videoURLProducesAVPlayerDriver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/a.mp4"))
        #expect(driver is AVPlayerDriver)
    }

    @Test func gifURLProducesGIFPlayerDriver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/a.gif"))
        #expect(driver is GIFPlayerDriver)
    }

    @Test func uppercaseGIFProducesGIFPlayerDriver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/A.GIF"))
        #expect(driver is GIFPlayerDriver)
    }
}
```

- [ ] **Step 2: 実装**

`Sources/MediaPlayerDriverFactory.swift` を新規作成:

```swift
import Foundation

@MainActor
struct MediaPlayerDriverFactory: PlayerDriverFactory {
    func makeDriver(for url: URL) -> PlayerDriver {
        if VideoFileType.isGIF(extension: url.pathExtension) {
            return GIFPlayerDriver()
        }
        return AVPlayerDriver()
    }
}
```

> `GIFPlayerDriver` は Phase 2 内 Task 6 で定義する。Phase 2 末まではビルド未完。

### Task 5: WallpaperWindowController を driver factory 化・observer/seek 撤去

**Files:**
- Modify: `Sources/WallpaperWindowController.swift`

- [ ] **Step 1: 全面書き換え**

`PlaybackContext` / `PlaybackCompletionObserver` / `seek` / `isPlaybackStartPending` / `currentObservationTarget` を撤去し、driver を URL ごとに生成・差し替える構造へ。`WallpaperWindowControlling` への準拠は維持する。

```swift
import AVFoundation
import Cocoa

@MainActor
final class WallpaperWindowController {

    private let window: NSWindow
    private var isWindowOrderedFront = false
    private let driverFactory: PlayerDriverFactory
    private let dimLayer: CALayer
    private let securityScopedAccessController: SecurityScopedAccessController
    private var driver: PlayerDriver?
    private var currentURL: URL?
    private var securityScopedAccessHandle: SecurityScopedAccessHandle?
    private var isPlaybackPaused = true
    private var occlusionObserver: NSObjectProtocol?

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFailed: (() -> Void)?

    convenience init(screen: NSScreen, videoURL url: URL?) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        self.init(
            window: window,
            videoURL: url,
            driverFactory: MediaPlayerDriverFactory(),
            securityScopedAccessController: URLSecurityScopedAccessController()
        )
    }

    init(
        window: NSWindow,
        videoURL url: URL?,
        driverFactory: PlayerDriverFactory,
        securityScopedAccessController: SecurityScopedAccessController
    ) {
        self.window = window
        self.driverFactory = driverFactory
        self.securityScopedAccessController = securityScopedAccessController

        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1
        )
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false

        let dropView = DropDestinationView(frame: window.frame)
        dropView.wantsLayer = true
        window.contentView = dropView

        dimLayer = CALayer()
        dimLayer.frame = dropView.bounds
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        dropView.layer?.addSublayer(dimLayer)
        applyDimLevel(DimLevel.saved.opacity)
        dropView.onVideoDropped = { [weak self] url in
            self?.onVideoDropped?(url)
        }

        if let url = url {
            load(videoURL: url)
            showWindowIfNeeded()
        }

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isWindowOrderedFront {
                    self.playIfNeeded()
                } else {
                    self.pausePlaybackIfNeeded()
                }
            }
        }
    }

    func applyDimLevel(_ opacity: CGFloat) {
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }

    func applyVideoGravity(_ gravity: VideoGravity) {
        driver?.applyGravity(gravity)
    }

    func load(videoURL url: URL) {
        guard currentURL != url else {
            if isWindowOrderedFront { playIfNeeded() }
            return
        }
        teardownDriver()
        currentURL = url
        securityScopedAccessHandle = securityScopedAccessController.startAccessing(url)

        let driver = driverFactory.makeDriver(for: url)
        driver.onPlaybackFailed = { [weak self] in
            self?.onPlaybackFailed?()
        }
        driver.applyGravity(VideoGravity.saved)
        if let hostLayer = window.contentView?.layer {
            driver.layer.frame = hostLayer.bounds
            driver.layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            hostLayer.insertSublayer(driver.layer, below: dimLayer)
        }
        self.driver = driver
        driver.load(url: url)
        isPlaybackPaused = true
        // orderFront / play は AppDelegate の applyBatteryPolicy() が制御する
    }

    func clearVideo() {
        guard isActive else { return }
        performClearVideo()
    }

    func resumePlayback() {
        guard currentURL != nil else { return }
        showWindowIfNeeded()
        playIfNeeded()
    }

    func pausePlayback() {
        pausePlaybackIfNeeded()
        hideWindowIfNeeded()
    }

    func invalidate() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        performClearVideo()
        window.close()
    }

    private var isActive: Bool {
        currentURL != nil || isWindowOrderedFront || !isPlaybackPaused
    }

    private func performClearVideo() {
        currentURL = nil
        teardownDriver()
        hideWindowIfNeeded()
    }

    private func teardownDriver() {
        driver?.pause()
        driver?.clear()
        driver?.layer.removeFromSuperlayer()
        driver = nil
        isPlaybackPaused = true
        stopScopedAccessIfNeeded()
    }

    private func showWindowIfNeeded() {
        guard !isWindowOrderedFront else { return }
        window.orderFront(nil)
        isWindowOrderedFront = true
    }

    private func hideWindowIfNeeded() {
        guard isWindowOrderedFront else { return }
        window.orderOut(nil)
        isWindowOrderedFront = false
    }

    private func pausePlaybackIfNeeded() {
        guard !isPlaybackPaused else { return }
        driver?.pause()
        isPlaybackPaused = true
    }

    private func playIfNeeded() {
        guard isPlaybackPaused else { return }
        guard driver != nil else { return }
        driver?.play()
        isPlaybackPaused = false
    }

    private func stopScopedAccessIfNeeded() {
        securityScopedAccessHandle?.stop()
        securityScopedAccessHandle = nil
    }
}

extension WallpaperWindowController: WallpaperWindowControlling {}

@MainActor
private final class DropDestinationView: NSView {

    var onVideoDropped: ((URL) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let url = fileURL(from: sender),
              VideoFileType.isSupported(extension: url.pathExtension) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender) else { return false }

        guard VideoFileType.isSupported(extension: url.pathExtension) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert.unsupported_file.title")
            alert.informativeText = String(localized: "alert.unsupported_file.message")
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }

        onVideoDropped?(url)
        return true
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: nil)?
            .first as? URL
    }
}
```

> `driver.layer` の host は `window.contentView?.layer`（= `DropDestinationView` の layer）。dimLayer は最前面を保つため `insertSublayer(_:below: dimLayer)` で常に dim の下へ入れる。

### Task 6: GIFPlayerDriver を実装

**Files:**
- Create: `Sources/GIFPlayerDriver.swift`

> GIF デコードの純粋ロジック（`GIFDecoder`）は Phase 3 Task 9 で作るが、型参照のため本タスクで `GIFDecoder` の API を前提に実装する。Phase 2 を実行する前に Phase 3（独立・ビルド可能）を先に完了しておくこと。**実行順序は Phase 1 → Phase 3 → Phase 2 → Phase 4 とする。**

- [ ] **Step 1: 実装**

`Sources/GIFPlayerDriver.swift` を新規作成:

```swift
import QuartzCore
import ImageIO

@MainActor
final class GIFPlayerDriver: PlayerDriver {
    let layer = CALayer()
    var onPlaybackFailed: (() -> Void)?

    private static let animationKey = "gifContents"

    func load(url: URL) {
        guard let decoded = GIFDecoder.decode(url: url) else {
            onPlaybackFailed?()
            return
        }
        layer.contents = decoded.images.last
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = decoded.images
        animation.keyTimes = decoded.keyTimes
        animation.duration = decoded.duration
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        layer.add(animation, forKey: Self.animationKey)
    }

    func play() {
        guard layer.speed == 0 else { return }
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timeSincePause
    }

    func pause() {
        guard layer.speed != 0 else { return }
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    func clear() {
        layer.removeAnimation(forKey: Self.animationKey)
        layer.contents = nil
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
    }

    func applyGravity(_ gravity: VideoGravity) {
        layer.contentsGravity = gravity.caGravity
    }
}
```

### Task 7: AppDelegate を刷新し playlist コードを削除

**Files:**
- Modify: `Sources/AppDelegate.swift`

- [ ] **Step 1: `WallpaperWindowControlling` protocol を刷新**

`Sources/AppDelegate.swift` 冒頭の protocol を以下へ置き換える（`onPlaybackFinished` 削除、`load` 簡素化）。`import IOKit.ps` は残す。

```swift
import AVFoundation
import Cocoa
import IOKit.ps

@MainActor
protocol WallpaperWindowControlling: AnyObject {
    var onVideoDropped: ((URL) -> Void)? { get set }
    var onPlaybackFailed: (() -> Void)? { get set }

    func load(videoURL url: URL)
    func clearVideo()
    func invalidate()
    func applyDimLevel(_ opacity: CGFloat)
    func applyVideoGravity(_ gravity: VideoGravity)
    func pausePlayback()
    func resumePlayback()
}
```

- [ ] **Step 2: playlist メンバとイニシャライザ引数を削除**

`AppDelegate` 本体から以下のプロパティを削除:
`playlistEditorWindowController` / `playlistPersistence` / `playlistStore`。
`init(...)` から `playlistStore: PlaylistStore = PlaylistPersistence().load()` 引数と `self.playlistStore = playlistStore` を削除する。残る init 引数は `screenProvider` / `controllerFactory` / `isOnBatteryProvider` / `wallpaperVideoStore`。

- [ ] **Step 3: controller 配線から onPlaybackFinished を削除**

`setupWallpaperWindows()` 内の controller 配線を更新:

```swift
            let controller = controllerFactory(screen)
            controller.onVideoDropped = { [weak self] url in
                self?.handleVideoSelected(url)
            }
            controller.onPlaybackFailed = { [weak self] in
                self?.setError(.playbackFailed)
                self?.updateMenuState()
            }
            controller.applyDimLevel(DimLevel.saved.opacity)
            controller.applyVideoGravity(VideoGravity.saved)
            newScreenControllers.append(ScreenController(id: id, controller: controller))
```

（`controller.onPlaybackFinished = { _ in }` 行を削除）

- [ ] **Step 4: applyGlobalVideo の load 呼び出しを簡素化**

```swift
        case .resolved(let url):
            clearError()
            controllers.forEach { $0.load(videoURL: url) }
```

- [ ] **Step 5: playlist 関連メソッドを全削除**

`AppDelegate` の `private extension`（266 行目以降）から以下を削除する:
`showPlaylistEditor()` / `makePlaylistEditorWindowController()` / `configure(editor:)` / `presentVideoOpenPanel()` / `reloadPlaylistUI()` / `deletePlaylistItem(id:)` / `movePlaylistItem(id:by:)` / `setCurrentPlaylistItem(id:)` / `updatePlaylistItem(mutation:)` / `persistPlaylistState()`。
残すのは `allControllers` / `updateMenuState()` / `setError(_:)` / `clearError()`。

### Task 8: playlist サブシステムと observer/completion を削除

**Files:**
- Delete: 下記ファイル

- [ ] **Step 1: production ファイルを削除**

```bash
git rm Sources/PlaylistModels.swift Sources/PlaybackSession.swift \
       Sources/RotationEngine.swift Sources/PlaylistPersistence.swift \
       Sources/PlaylistEditorWindowController.swift \
       Sources/PlaybackCompletion.swift Sources/PlaybackCompletionObserver.swift
```

- [ ] **Step 2: テストファイルを削除**

```bash
git rm Tests/VideoWallpaperTests/PlaylistStoreTests.swift \
       Tests/VideoWallpaperTests/PlaylistStoreMutationTests.swift \
       Tests/VideoWallpaperTests/PlaylistPersistenceTests.swift \
       Tests/VideoWallpaperTests/PlaybackSessionTests.swift \
       Tests/VideoWallpaperTests/RotationEngineTests.swift \
       Tests/VideoWallpaperTests/PlaylistEditorWindowControllerTests.swift
```

- [ ] **Step 3: ローカライズ文字列を削除**

`Sources/Localizable.xcstrings` から `menu.playlist.*` と `playlist_editor.*`（`playlist_editor.validation.invalid_range` 含む）のキーを削除する。JSON の `strings` オブジェクトから該当キーごと削除。

### Task 9: テストヘルパとテストを新構造へ書き換え

**Files:**
- Modify: `Tests/.../WallpaperWindowTestHelpers.swift`
- Modify: `Tests/.../Support/FakeWallpaperWindowController.swift`
- Modify: `Tests/.../WallpaperWindowControllerTests.swift`
- Modify: `Tests/.../WallpaperWindowControllerVisibilityTests.swift`
- Modify: `Tests/.../PlaybackDriverTests.swift`
- Modify: `Tests/.../PlaybackFailureTests.swift`

- [ ] **Step 1: `WallpaperWindowTestHelpers.swift` の Fake driver を刷新**

`FakePlayerDriver` を新 protocol へ。`FakePlaybackObservationTarget` / `FakePlaybackCompletionObserver` を削除。`WallpaperWindowControllerTestContext` から `observer` を除去し、`FakePlayerDriverFactory` を `makeDriver(for:)` 形に。

```swift
@MainActor
struct WallpaperWindowControllerTestContext {
    let window: FakeWindow
    let driver: FakePlayerDriver
    let factory: FakePlayerDriverFactory
    let accessController: FakeSecurityScopedAccessController
    let controller: WallpaperWindowController

    init() throws {
        let window = FakeWindow(contentRect: try makeScreen().frame)
        let driver = FakePlayerDriver()
        let factory = FakePlayerDriverFactory(driver: driver)
        let accessController = FakeSecurityScopedAccessController()

        self.window = window
        self.driver = driver
        self.factory = factory
        self.accessController = accessController
        controller = WallpaperWindowController(
            window: window,
            videoURL: nil,
            driverFactory: factory,
            securityScopedAccessController: accessController
        )
    }
}

@MainActor
final class FakePlayerDriverFactory: PlayerDriverFactory {
    let driver: FakePlayerDriver
    private(set) var requestedURLs: [URL] = []

    init(driver: FakePlayerDriver) {
        self.driver = driver
    }

    func makeDriver(for url: URL) -> PlayerDriver {
        requestedURLs.append(url)
        return driver
    }
}

@MainActor
final class FakePlayerDriver: PlayerDriver {
    let layer = CALayer()
    var onPlaybackFailed: (() -> Void)?

    private(set) var loadedURLs: [URL] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearCallCount = 0
    private(set) var appliedGravities: [VideoGravity] = []

    func load(url: URL) { loadedURLs.append(url) }
    func play() { playCallCount += 1 }
    func pause() { pauseCallCount += 1 }
    func clear() { clearCallCount += 1 }
    func applyGravity(_ gravity: VideoGravity) { appliedGravities.append(gravity) }

    func emitPlaybackFailed() { onPlaybackFailed?() }
}
```

`FakeWindow` / `FakeSecurityScopedAccessHandle` / `FakeSecurityScopedAccessController` / `makeScreen` / `wallpaperWindowTestURL` はそのまま残す。`import AppKit` `import QuartzCore` を確保。

- [ ] **Step 2: `FakeWallpaperWindowController.swift` を新シグネチャへ**

```swift
import AVFoundation
import Foundation
@testable import VideoWallpaper

@MainActor
final class FakeWallpaperWindowController: WallpaperWindowControlling {

    var onVideoDropped: ((URL) -> Void)?
    var onPlaybackFailed: (() -> Void)?

    private(set) var loadCallCount = 0
    private(set) var loadedURLs: [URL] = []
    private(set) var resumeCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var clearVideoCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var applyDimLevelCallCount = 0
    private(set) var applyVideoGravityCallCount = 0

    func load(videoURL url: URL) {
        loadCallCount += 1
        loadedURLs.append(url)
    }

    func clearVideo() { clearVideoCallCount += 1 }
    func invalidate() { invalidateCallCount += 1 }
    func applyDimLevel(_ opacity: CGFloat) { applyDimLevelCallCount += 1 }
    func applyVideoGravity(_ gravity: VideoGravity) { applyVideoGravityCallCount += 1 }
    func pausePlayback() { pauseCallCount += 1 }
    func resumePlayback() { resumeCallCount += 1 }
}
```

- [ ] **Step 3: `WallpaperWindowControllerTests.swift` を書き換え**

`timeRange` / `itemID` / `token` / `onPlaybackFinished` / `observer` / seek / `forwardPlaybackEndTime` を参照する全テストを削除し、新しい振る舞いに沿うテストへ置換。最低限残す/作るケース:

```swift
@MainActor
struct WallpaperWindowControllerTests {
    @Test func loadCreatesDriverAndLoadsURL() throws {
        let ctx = try WallpaperWindowControllerTestContext()
        let url = wallpaperWindowTestURL("a.mp4")
        ctx.controller.load(videoURL: url)
        #expect(ctx.factory.requestedURLs == [url])
        #expect(ctx.driver.loadedURLs == [url])
    }

    @Test func loadSameURLDoesNotReload() throws {
        let ctx = try WallpaperWindowControllerTestContext()
        let url = wallpaperWindowTestURL("a.mp4")
        ctx.controller.load(videoURL: url)
        ctx.controller.load(videoURL: url)
        #expect(ctx.driver.loadedURLs == [url])
    }

    @Test func resumeThenPauseDrivesPlayer() throws {
        let ctx = try WallpaperWindowControllerTestContext()
        ctx.controller.load(videoURL: wallpaperWindowTestURL("a.mp4"))
        ctx.controller.resumePlayback()
        #expect(ctx.driver.playCallCount == 1)
        ctx.controller.pausePlayback()
        #expect(ctx.driver.pauseCallCount >= 1)
    }

    @Test func clearVideoTearsDownDriverAndScopedAccess() throws {
        let ctx = try WallpaperWindowControllerTestContext()
        ctx.controller.load(videoURL: wallpaperWindowTestURL("a.mp4"))
        ctx.controller.clearVideo()
        #expect(ctx.driver.clearCallCount >= 1)
        #expect(ctx.accessController.handles.first?.stopCount == 1)
    }

    @Test func applyVideoGravityForwardsToDriver() throws {
        let ctx = try WallpaperWindowControllerTestContext()
        ctx.controller.load(videoURL: wallpaperWindowTestURL("a.mp4"))
        ctx.controller.applyVideoGravity(.fit)
        #expect(ctx.driver.appliedGravities.contains(.fit))
    }
}
```

- [ ] **Step 4: `WallpaperWindowControllerVisibilityTests.swift` を書き換え**

`CMTimeRange` 引数や seek 完了に依存するケースを削除。window の orderFront/orderOut とバッテリポリシ経路（`resumePlayback` / `pausePlayback`）の可視性テストを `FakeWindow.orderFrontCallCount` / `orderOutCallCount` で検証する形へ更新する。seek pending に関するケースは削除する。

- [ ] **Step 5: `PlaybackDriverTests.swift` を書き換え**

旧 `replaceCurrentItem` / `seek` / `forwardPlaybackEndTime` のテストを削除。新 `AVPlayerDriver` について、`applyGravity(.fit)` が `layer.videoGravity == .resizeAspect` になること、`load` 後に `layer.player` が非 nil であること、`clear()` で `player.items()` が空になることを検証する。

```swift
import AVFoundation
import Testing
@testable import VideoWallpaper

@MainActor
struct PlaybackDriverTests {
    @Test func applyGravityMapsToVideoGravity() {
        let driver = AVPlayerDriver()
        driver.applyGravity(.fit)
        #expect(driver.layer.videoGravity == .resizeAspect)
    }

    @Test func clearRemovesAllItems() {
        let driver = AVPlayerDriver()
        driver.load(url: URL(fileURLWithPath: "/tmp/a.mp4"))
        driver.clear()
        if let queue = driver.layer.player as? AVQueuePlayer {
            #expect(queue.items().isEmpty)
        }
    }
}
```

- [ ] **Step 6: `PlaybackFailureTests.swift` を書き換え**

driver の `onPlaybackFailed` → controller の `onPlaybackFailed` → AppDelegate のエラー表示までの転送を、`FakePlayerDriver.emitPlaybackFailed()` を起点に検証する形へ。AppDelegate 層のテスト（`AppDelegateWallpaperStoreTests` の様式）に合わせ、`FakeWallpaperWindowController` 経由でないものは controller 単体の転送を確認する:

```swift
@Test func driverFailureForwardsToController() throws {
    let ctx = try WallpaperWindowControllerTestContext()
    var failed = false
    ctx.controller.onPlaybackFailed = { failed = true }
    ctx.controller.load(videoURL: wallpaperWindowTestURL("a.mp4"))
    ctx.driver.emitPlaybackFailed()
    #expect(failed)
}
```

### Task 10: Phase 2 のビルドと全テスト確認・コミット

- [ ] **Step 1: XcodeGen 再生成**（新規 `.swift` 追加と削除を反映）

Run: `xcodegen generate`

- [ ] **Step 2: ビルド**

Run: `make build`
Expected: ビルド成功（警告のみ可）

- [ ] **Step 3: 全テスト**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'`
Expected: 全テスト PASS（削除したテストは存在しない）

- [ ] **Step 4: AppDelegate 系テストの追従確認**

`AppDelegateWallpaperStoreTests` / `AppDelegateScreenLifecycleTests` が `FakeWallpaperWindowController` の新 `load(videoURL:)` で緑になっていること。`onPlaybackFinished` を参照する箇所が残っていれば削除する。

- [ ] **Step 5: コミット**

```bash
git add -A
git commit -m "refactor: driver-owned looping, remove playlist subsystem and timeRange"
```

---

## Phase 3: GIF デコードの純粋ロジック（独立・先行実行）

> **このフェーズは Phase 2 より先に実行する**（`GIFPlayerDriver` / `MediaPlayerDriverFactory` が `GIFDecoder` を参照するため）。ただし `GIFDecoder` 自体は既存コードに依存せず単体でビルド・テスト可能。

### Task 11: GIFDecoder の keyTimes / duration 計算

**Files:**
- Create: `Sources/GIFDecoder.swift`
- Test: `Tests/VideoWallpaperTests/GIFDecoderTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`GIFDecoderTests.swift` を新規作成:

```swift
import Testing
@testable import VideoWallpaper

struct GIFDecoderTests {
    @Test func keyTimesAreCumulativeStartTimesNormalized() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.1, 0.1, 0.2])
        #expect(result.duration == 0.4)
        let values = result.keyTimes.map { $0.doubleValue }
        #expect(values.count == 3)
        #expect(abs(values[0] - 0.0) < 1e-9)
        #expect(abs(values[1] - 0.25) < 1e-9)
        #expect(abs(values[2] - 0.5) < 1e-9)
    }

    @Test func zeroOrTinyDelayIsClampedToMinimum() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.0, 0.0])
        // 各 delay は 0.1 にクランプされ duration = 0.2
        #expect(abs(result.duration - 0.2) < 1e-9)
    }

    @Test func singleFrameProducesZeroKeyTimeAndPositiveDuration() {
        let result = GIFDecoder.makeKeyTimes(delays: [0.1])
        #expect(result.keyTimes.map { $0.doubleValue } == [0.0])
        #expect(abs(result.duration - 0.1) < 1e-9)
    }

    @Test func emptyDelaysProducesZeroDuration() {
        let result = GIFDecoder.makeKeyTimes(delays: [])
        #expect(result.keyTimes.isEmpty)
        #expect(result.duration == 0)
    }
}
```

- [ ] **Step 2: 失敗を確認**

Run: `xcodegen generate && xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/GIFDecoderTests`
Expected: FAIL（`GIFDecoder` 未定義）

- [ ] **Step 3: 実装**

`Sources/GIFDecoder.swift` を新規作成:

```swift
import CoreGraphics
import Foundation
import ImageIO

enum GIFDecoder {

    /// GIF 各ブラウザ慣習に合わせた最小フレーム表示時間。
    static let minimumFrameDelay: Double = 0.1
    private static let delayThreshold: Double = 0.011

    struct DecodedGIF {
        let images: [CGImage]
        let keyTimes: [NSNumber]
        let duration: Double
    }

    /// フレーム delay 列から CAKeyframeAnimation 用の正規化 keyTimes と総時間を計算する純粋関数。
    static func makeKeyTimes(delays: [Double]) -> (keyTimes: [NSNumber], duration: Double) {
        let clamped = delays.map { $0 < delayThreshold ? minimumFrameDelay : $0 }
        let duration = clamped.reduce(0, +)
        guard duration > 0 else { return ([], 0) }

        var cumulative = 0.0
        var keyTimes: [NSNumber] = []
        for delay in clamped {
            keyTimes.append(NSNumber(value: cumulative / duration))
            cumulative += delay
        }
        return (keyTimes, duration)
    }

    /// 単一フレームの delay 秒を ImageIO から取得する。Unclamped を優先する。
    static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
            as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return minimumFrameDelay
        }
        if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double {
            return clamped
        }
        return minimumFrameDelay
    }

    /// URL から全フレームと keyTimes をデコードする。失敗時は nil。
    static func decode(url: URL) -> DecodedGIF? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var images: [CGImage] = []
        var delays: [Double] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(image)
            delays.append(frameDelay(source: source, index: index))
        }
        guard !images.isEmpty else { return nil }

        let (keyTimes, duration) = makeKeyTimes(delays: delays)
        guard duration > 0 else { return nil }
        return DecodedGIF(images: images, keyTimes: keyTimes, duration: duration)
    }
}
```

- [ ] **Step 4: テスト緑を確認**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/GIFDecoderTests`
Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add Sources/GIFDecoder.swift Tests/VideoWallpaperTests/GIFDecoderTests.swift
git commit -m "feat: add GIFDecoder for frame delay and keyTimes computation"
```

---

## Phase 4: GIF driver / factory のコミットと結線確認

> `GIFPlayerDriver.swift`（Task 6）と `MediaPlayerDriverFactory.swift`（Task 4）は Phase 2 のコミットに含まれている。本フェーズではそれらのテスト（`MediaPlayerDriverFactoryTests`）が緑であることと、GIF 実機再生を確認する。

### Task 12: factory テスト緑とアプリ起動確認

- [ ] **Step 1: factory テスト**

Run: `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS' -only-testing:VideoWallpaperTests/MediaPlayerDriverFactoryTests`
Expected: PASS

- [ ] **Step 2: アプリをビルドして起動**

Run: `make run`
Expected: ビルド成功・アプリ起動（メニューバーアイコン表示）

- [ ] **Step 3: GIF を適用して実機確認（手動）**

メニューの「動画を選択」または壁紙ウィンドウへのドラッグ&ドロップで `.gif` を選び、以下を確認:
- GIF が壁紙としてループ再生される
- 明るさ調整（Dim）が GIF にも効く
- 表示方法（Cover/Contain/Fill = fill/fit/stretch）切り替えが GIF に反映される
- 低電力モードで pause、復帰で resume する
- 動画（mp4）に戻しても従来どおり AVPlayerLooper でループ再生される

---

## Phase 5: 仕上げ（ドキュメント更新）

### Task 13: CONTEXT.md / todo.md / knowledge.md / ADR を更新

**Files:**
- Modify: `CONTEXT.md` / `tasks/todo.md` / `tasks/knowledge.md` / `docs/adr/2026-06-19-gif-support-and-playlist-removal.md`

- [ ] **Step 1: CONTEXT.md の用語更新**

playlist 関連用語（PlaylistStore / PlaybackSession / RotationEngine / timeRange 等）を削除し、GIF / driver 種別（`AVPlayerDriver` / `GIFPlayerDriver` / `MediaPlayerDriverFactory`）を追記する。

- [ ] **Step 2: tasks/todo.md の playlist タスク削除**

「Audit follow-up: 2026-06-10」の P1/P2 から playlist 関連項目（production menu 接続 / `PlaybackSession` 統合 / ローテーション integration test / `PlaylistPersistence` 分離 / `PlaylistStore`・`RotationEngine` mutator 等）を削除する。完了済みでなく「不要化」のため、セクション末に「playlist サブシステムは ADR 2026-06-19 で全削除」と一行残す。

- [ ] **Step 3: tasks/knowledge.md に学びを追記**

「GIF は AVFoundation で再生不可、ImageIO+CAKeyframeAnimation で CALayer 描画」「ループは driver 責務に統一（AVPlayerLooper / CAKeyframeAnimation）」「playlist は到達不能 dead code だった」を追記。

- [ ] **Step 4: ADR の status を accepted に更新**

`docs/adr/2026-06-19-gif-support-and-playlist-removal.md` の Front Matter `status: proposed` を `status: accepted` に変更。

- [ ] **Step 5: 最終ビルド・テスト・コミット**

```bash
xcodegen generate
make build
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
git add -A
git commit -m "docs: update CONTEXT/todo/knowledge and accept ADR for GIF support"
```

---

## 実行順序まとめ

ビルド整合のため、フェーズ番号順ではなく以下の順で実行する:

1. **Phase 1**（Task 1–2）: VideoGravity / VideoFileType 追加 — 独立・各コミット
2. **Phase 3**（Task 11）: GIFDecoder — 独立・コミット
3. **Phase 2**（Task 3–10）: driver/controller/AppDelegate 刷新 + playlist 削除 + GIFPlayerDriver/factory — 協調変更・1 コミット
4. **Phase 4**（Task 12）: factory テスト緑 + GIF 実機確認
5. **Phase 5**（Task 13）: ドキュメント更新 — コミット

## 受け入れ基準

- `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'` 全緑
- `make run` でアプリ起動
- `.gif` をドラッグ&ドロップ / 選択で壁紙としてループ再生され、Dim / 表示方法 / 低電力 pause が効く
- mp4/mov/m4v が AVPlayerLooper で従来どおりループ再生される
- playlist 関連コード・テスト・ローカライズ文字列が repo に存在しない
