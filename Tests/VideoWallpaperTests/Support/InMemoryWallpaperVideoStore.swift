import Foundation
@testable import VideoWallpaper

/// WallpaperVideoStoring の in-memory fake（2 つ目の adapter = real seam）。
final class InMemoryWallpaperVideoStore: WallpaperVideoStoring {

    var video: URL?
    /// resolve 結果を強制上書きする（resolveFailed の再現用）。
    var resolveOverride: ResolvedVideo?
    var saveShouldFail = false

    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0

    func resolveVideo() -> ResolvedVideo {
        if let resolveOverride { return resolveOverride }
        if let video { return .resolved(video) }
        return .noVideo
    }

    @discardableResult
    func saveVideo(_ url: URL) -> Bool {
        saveCallCount += 1
        guard !saveShouldFail else { return false }
        video = url
        return true
    }

    func clearVideo() {
        clearCallCount += 1
        video = nil
    }
}
