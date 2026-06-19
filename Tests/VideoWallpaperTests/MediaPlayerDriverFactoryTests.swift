import Foundation
import Testing
@testable import VideoWallpaper

@MainActor
struct MediaPlayerDriverFactoryTests {

    @Test func video_url_produces_av_player_driver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/a.mp4"))
        #expect(driver is AVPlayerDriver)
    }

    @Test func mov_url_produces_av_player_driver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/a.mov"))
        #expect(driver is AVPlayerDriver)
    }

    @Test func gif_url_produces_gif_player_driver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/a.gif"))
        #expect(driver is GIFPlayerDriver)
    }

    @Test func uppercase_gif_url_produces_gif_player_driver() {
        let factory = MediaPlayerDriverFactory()
        let driver = factory.makeDriver(for: URL(fileURLWithPath: "/tmp/A.GIF"))
        #expect(driver is GIFPlayerDriver)
    }
}
