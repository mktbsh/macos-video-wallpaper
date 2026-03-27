import AVFoundation
import Foundation

@MainActor
protocol PlaybackCompletionObserver {
    func observePlaybackCompletion(
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

    func cancelObservation(_ token: AnyObject) {
        guard let token = token as? NotificationPlaybackObservationToken else { return }
        notificationCenter.removeObserver(token.token)
    }
}
