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
    /// クランプ（0 以下や極小値の補正）は makeKeyTimes が担う。
    static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
            as? [String: Any],
            let gif = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        else {
            return minimumFrameDelay
        }
        if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double {
            return unclamped
        }
        if let clamped = gif[kCGImagePropertyGIFDelayTime as String] as? Double {
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
