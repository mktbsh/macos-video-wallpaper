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

    var effectiveDisplayName: String {
        displayName.isEmpty ? url.lastPathComponent : displayName
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
    private var playbackToken: RotationEngine<PlaylistItem>.PlaybackToken

    init(items: [PlaylistItem] = [], currentItemID: PlaylistItem.ID? = nil) {
        engine = RotationEngine(entries: items, currentEntryID: currentItemID)
        playbackToken = engine.beginPlayback()
    }

    var items: [PlaylistItem] {
        engine.entries
    }

    var currentItem: PlaylistItem? {
        guard let currentEntryID = engine.currentEntryID else { return nil }
        return items.first(where: { $0.id == currentEntryID })
    }

    var summary: PlaylistSummary? {
        guard let currentItem, !items.isEmpty else { return nil }
        return PlaylistSummary(
            itemCount: items.count,
            currentDisplayName: currentItem.effectiveDisplayName
        )
    }

    mutating func replace(urls: [URL]) {
        let newItems = urls.map { PlaylistItem(url: $0) }
        let currentID = newItems.first?.id
        engine.replace(entries: newItems, currentEntryID: currentID)
    }

    mutating func add(urls: [URL]) {
        let newItems = urls.map { PlaylistItem(url: $0) }
        guard !newItems.isEmpty else { return }

        let newEntries = items + newItems
        let currentID = engine.currentEntryID ?? newEntries.first?.id
        engine.replace(entries: newEntries, currentEntryID: currentID)
    }

    mutating func clear() {
        engine.replace(entries: [], currentEntryID: nil)
    }

    mutating func next() -> Bool {
        engine.next(using: playbackToken)
    }

    mutating func previous() -> Bool {
        engine.previous(using: playbackToken)
    }

    mutating func setCurrent(id: PlaylistItem.ID) -> Bool {
        guard items.contains(where: { $0.id == id }) else { return false }
        engine.replace(entries: items, currentEntryID: id)
        return true
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
        updateItem(id: id) { $0.displayName = displayName }
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

    mutating func updateStartTime(id: PlaylistItem.ID, startTime: Double?) -> Bool {
        updateItem(id: id) { $0.startTime = startTime }
    }

    mutating func updateEndTime(id: PlaylistItem.ID, endTime: Double?) -> Bool {
        updateItem(id: id) { $0.endTime = endTime }
    }

    private mutating func updateItem(
        id: PlaylistItem.ID,
        transform: (inout PlaylistItem) -> Void
    ) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }

        var newEntries = items
        transform(&newEntries[index])
        engine.replace(entries: newEntries, currentEntryID: engine.currentEntryID)
        return true
    }
}
