import Foundation

struct PlaybackCompletion: Equatable {
    let itemID: PlaylistItem.ID
    let token: RotationEngine<PlaylistItem>.PlaybackToken
}
