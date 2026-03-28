import AVFoundation
import Foundation

@MainActor
protocol PlaybackObservationTarget: AnyObject {}

@MainActor
protocol PlayerDriver: AnyObject {
    var layer: AVPlayerLayer { get }

    @discardableResult
    func replaceCurrentItem(with url: URL, forwardPlaybackEndTime: CMTime?) -> PlaybackObservationTarget
    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completion: @escaping @MainActor (Bool) -> Void
    )
    func play()
    func pause()
    func clearCurrentItem()
}

@MainActor
protocol PlayerDriverFactory {
    func makeDriver() -> PlayerDriver
}

@MainActor
final class AVPlayerObservationTarget: NSObject, PlaybackObservationTarget {
    let item: AVPlayerItem

    init(item: AVPlayerItem) {
        self.item = item
    }
}

@MainActor
final class AVPlayerDriver: PlayerDriver {
    let layer: AVPlayerLayer

    private let player: AVPlayer

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        player.isMuted = true
        layer = AVPlayerLayer(player: player)
    }

    @discardableResult
    func replaceCurrentItem(with url: URL, forwardPlaybackEndTime: CMTime?) -> PlaybackObservationTarget {
        let item = AVPlayerItem(url: url)
        if let forwardPlaybackEndTime {
            item.forwardPlaybackEndTime = forwardPlaybackEndTime
        }
        player.replaceCurrentItem(with: item)
        return AVPlayerObservationTarget(item: item)
    }

    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        player.seek(
            to: time,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        ) { finished in
            Task { @MainActor in
                completion(finished)
            }
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func clearCurrentItem() {
        player.replaceCurrentItem(with: nil)
    }
}

@MainActor
struct AVPlayerDriverFactory: PlayerDriverFactory {
    func makeDriver() -> PlayerDriver {
        AVPlayerDriver()
    }
}
