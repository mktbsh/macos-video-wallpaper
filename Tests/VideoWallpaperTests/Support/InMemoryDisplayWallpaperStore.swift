import Foundation
@testable import VideoWallpaper

/// DisplayWallpaperStoring の in-memory fake（2 つ目の adapter = real seam）。
final class InMemoryDisplayWallpaperStore: DisplayWallpaperStoring {

    var videos: [DisplayIdentifier: URL] = [:]
    var enabled: [DisplayIdentifier: Bool] = [:]
    /// 指定した display の resolve 結果を強制上書きする（resolveFailed の再現用）。
    var resolveOverrides: [DisplayIdentifier: ResolvedVideo] = [:]
    var saveShouldFail = false

    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0

    func resolveVideo(for display: DisplayIdentifier) -> ResolvedVideo {
        if let override = resolveOverrides[display] { return override }
        if let url = videos[display] { return .resolved(url) }
        return .noVideo
    }

    @discardableResult
    func saveVideo(_ url: URL, for display: DisplayIdentifier) -> Bool {
        saveCallCount += 1
        guard !saveShouldFail else { return false }
        videos[display] = url
        return true
    }

    func clearVideo(for display: DisplayIdentifier) {
        clearCallCount += 1
        videos[display] = nil
    }

    func isEnabled(_ display: DisplayIdentifier) -> Bool {
        enabled[display] ?? true
    }

    func setEnabled(_ enabled: Bool, for display: DisplayIdentifier) {
        self.enabled[display] = enabled
    }
}
