import AVFoundation
import Foundation

struct PlaylistItem: Identifiable, Equatable {

    let id: UUID
    var url: URL
    var displayName: String
    var useFullVideo: Bool
    var startTime: Double?
    var endTime: Double?

    init(
        id: UUID = UUID(),
        url: URL,
        displayName: String = "",
        useFullVideo: Bool = true,
        startTime: Double? = nil,
        endTime: Double? = nil
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName.isEmpty ? url.lastPathComponent : displayName
        self.useFullVideo = useFullVideo
        self.startTime = startTime
        self.endTime = endTime
    }

    mutating func setDisplayName(_ name: String) {
        displayName = name.isEmpty ? url.lastPathComponent : name
    }

    var playbackTimeRange: CMTimeRange? {
        guard !useFullVideo,
              let startTime,
              let endTime,
              endTime > startTime else { return nil }

        return CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
    }
}

struct PlaylistSummary: Equatable {
    let itemCount: Int
    let currentDisplayName: String?
}

struct PlaylistStore {

    private var engine: RotationEngine<PlaylistItem>

    init(items: [PlaylistItem] = [], currentItemID: PlaylistItem.ID? = nil) {
        engine = RotationEngine(entries: items, currentEntryID: currentItemID)
    }

    var items: [PlaylistItem] {
        engine.entries
    }

    var currentItem: PlaylistItem? {
        guard let id = engine.currentEntryID else { return nil }
        return items.first(where: { $0.id == id })
    }

    var summary: PlaylistSummary? {
        guard let currentItem else { return nil }
        return PlaylistSummary(
            itemCount: items.count,
            currentDisplayName: currentItem.displayName
        )
    }

    mutating func replace(items newItems: [PlaylistItem], currentItemID: PlaylistItem.ID?) {
        engine.replace(entries: newItems, currentEntryID: currentItemID)
    }

    mutating func add(urls: [URL]) {
        guard !urls.isEmpty else { return }
        engine.replace(entries: items + urls.map { PlaylistItem(url: $0) }, currentEntryID: engine.currentEntryID)
    }

    mutating func clear() {
        engine.replace(entries: [], currentEntryID: nil)
    }

    mutating func next() -> Bool {
        engine.next()
    }

    mutating func previous() -> Bool {
        engine.previous()
    }

    mutating func beginPlayback() -> RotationEngine<PlaylistItem>.PlaybackToken {
        engine.beginPlayback()
    }

    mutating func advanceAfterPlaybackCompletion(
        using token: RotationEngine<PlaylistItem>.PlaybackToken
    ) -> Bool {
        engine.advanceAfterPlaybackCompletion(using: token)
    }

    mutating func setCurrent(id: PlaylistItem.ID) -> Bool {
        engine.setCurrent(id: id)
    }

    mutating func delete(id: PlaylistItem.ID) -> Bool {
        guard let removedIndex = items.firstIndex(where: { $0.id == id }) else { return false }

        var newEntries = items
        newEntries.remove(at: removedIndex)

        let newCurrentID: PlaylistItem.ID?
        if newEntries.isEmpty {
            newCurrentID = nil
        } else if engine.currentEntryID == id {
            newCurrentID = newEntries[min(removedIndex, newEntries.count - 1)].id
        } else {
            newCurrentID = engine.currentEntryID
        }

        engine.replace(entries: newEntries, currentEntryID: newCurrentID)
        return true
    }

    mutating func move(id: PlaylistItem.ID, by offset: Int) -> Bool {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return false }
        let destinationIndex = sourceIndex + offset
        guard items.indices.contains(destinationIndex) else { return false }

        var newEntries = items
        let item = newEntries.remove(at: sourceIndex)
        newEntries.insert(item, at: destinationIndex)
        engine.replace(entries: newEntries, currentEntryID: engine.currentEntryID)
        return true
    }

    mutating func updateDisplayName(id: PlaylistItem.ID, displayName: String) -> Bool {
        updateItem(id: id) { $0.setDisplayName(displayName) }
    }

    mutating func updateUseFullVideo(id: PlaylistItem.ID, useFullVideo: Bool) -> Bool {
        updateItem(id: id) {
            $0.useFullVideo = useFullVideo
            if useFullVideo {
                $0.startTime = nil
                $0.endTime = nil
            }
        }
    }

    mutating func updateTimeRange(
        id: PlaylistItem.ID,
        startTime: Double?,
        endTime: Double?
    ) -> Bool {
        updateItem(id: id) {
            $0.startTime = startTime
            $0.endTime = endTime
        }
    }

    private mutating func updateItem(
        id: PlaylistItem.ID,
        transform: (inout PlaylistItem) -> Void
    ) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }

        var newEntries = items
        let originalItem = newEntries[index]
        transform(&newEntries[index])
        guard newEntries[index] != originalItem else { return false }
        engine.replace(entries: newEntries, currentEntryID: engine.currentEntryID)
        return true
    }
}
