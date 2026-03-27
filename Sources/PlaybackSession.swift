import Foundation

struct PlaybackSession {

    struct PlaybackRequest: Equatable {
        let item: PlaylistItem
        let token: RotationEngine<PlaylistItem>.PlaybackToken
    }

    private(set) var currentToken: RotationEngine<PlaylistItem>.PlaybackToken?

    mutating func beginPlayback(using store: inout PlaylistStore) -> PlaybackRequest? {
        guard let item = store.currentItem else {
            currentToken = nil
            return nil
        }

        let token = store.beginPlayback()
        currentToken = token
        return PlaybackRequest(item: item, token: token)
    }

    mutating func consume(
        _ completion: PlaybackCompletion,
        using store: inout PlaylistStore
    ) -> Bool {
        guard currentToken == completion.token else { return false }
        currentToken = nil
        return store.advanceAfterPlaybackCompletion(using: completion.token)
    }
}
