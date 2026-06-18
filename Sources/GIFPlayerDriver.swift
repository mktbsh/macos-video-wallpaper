import ImageIO
import QuartzCore

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
        // play() が呼ばれるまで停止状態で保持する（低電力モードで非表示のまま
        // GIF が回り続けるのを防ぐ）。play() は局所時刻 0 から再生を開始する。
        layer.speed = 0
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
