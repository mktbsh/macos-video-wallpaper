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
