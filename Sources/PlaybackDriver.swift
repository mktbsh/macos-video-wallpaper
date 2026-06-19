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
    var layer: CALayer { playerLayer }
    var onPlaybackFailed: (() -> Void)?

    private let playerLayer: AVPlayerLayer
    private let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        playerLayer = AVPlayerLayer(player: player)
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
        playerLayer.videoGravity = gravity.avGravity
    }
}
