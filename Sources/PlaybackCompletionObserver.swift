import AVFoundation
import Foundation

@MainActor
protocol PlaybackCompletionObserver {
    func observePlaybackCompletion(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject
    func observePlaybackFailure(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject
    func cancelObservation(_ token: AnyObject)
}

@MainActor
private final class NotificationPlaybackObservationToken: NSObject {
    let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }
}

@MainActor
private final class KVOPlaybackObservationToken: NSObject {
    let observation: NSKeyValueObservation

    init(observation: NSKeyValueObservation) {
        self.observation = observation
    }
}

@MainActor
struct NotificationPlaybackCompletionObserver: PlaybackCompletionObserver {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func observePlaybackCompletion(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject {
        guard let target = target as? AVPlayerObservationTarget else {
            fatalError("Unexpected playback observation target: \(type(of: target))")
        }

        let token = notificationCenter.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: target.item,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        }
        return NotificationPlaybackObservationToken(token: token)
    }

    func observePlaybackFailure(
        for target: PlaybackObservationTarget,
        handler: @escaping @MainActor () -> Void
    ) -> AnyObject {
        guard let target = target as? AVPlayerObservationTarget else {
            fatalError("Unexpected playback observation target: \(type(of: target))")
        }

        let observation = target.item.observe(
            \.status,
            options: [.new]
        ) { item, _ in
            guard item.status == .failed else { return }
            MainActorCompletionRelay.run {
                handler()
            }
        }
        return KVOPlaybackObservationToken(observation: observation)
    }

    func cancelObservation(_ token: AnyObject) {
        if let token = token as? NotificationPlaybackObservationToken {
            notificationCenter.removeObserver(token.token)
        } else if let token = token as? KVOPlaybackObservationToken {
            token.observation.invalidate()
        }
    }
}
