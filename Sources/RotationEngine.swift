import Foundation

struct RotationEngine<Entry: Identifiable> {

    struct PlaybackToken: Equatable {
        fileprivate let generation: Int
    }

    private(set) var entries: [Entry]
    private(set) var currentEntryID: Entry.ID?

    private var playbackGeneration = 0
    private var activePlaybackGeneration: Int?

    init(entries: [Entry] = [], currentEntryID: Entry.ID? = nil) {
        self.entries = entries
        if let currentEntryID, entries.contains(where: { $0.id == currentEntryID }) {
            self.currentEntryID = currentEntryID
        } else {
            self.currentEntryID = entries.first?.id
        }
    }

    mutating func beginPlayback() -> PlaybackToken {
        playbackGeneration += 1
        activePlaybackGeneration = playbackGeneration
        return PlaybackToken(generation: playbackGeneration)
    }

    mutating func next() -> Bool {
        guard let nextIndex = index(offsetBy: 1) else { return false }
        currentEntryID = entries[nextIndex].id
        return true
    }

    mutating func previous() -> Bool {
        guard let previousIndex = index(offsetBy: -1) else { return false }
        currentEntryID = entries[previousIndex].id
        return true
    }

    mutating func setCurrent(id: Entry.ID) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        currentEntryID = id
        return true
    }

    mutating func advanceAfterPlaybackCompletion(using token: PlaybackToken) -> Bool {
        guard isCurrentPlayback(token), let nextIndex = index(offsetBy: 1) else { return false }
        currentEntryID = entries[nextIndex].id
        return true
    }

    mutating func replace(entries newEntries: [Entry], currentEntryID: Entry.ID?) {
        entries = newEntries
        if let currentEntryID, newEntries.contains(where: { $0.id == currentEntryID }) {
            self.currentEntryID = currentEntryID
        } else if let currentEntryID = self.currentEntryID,
                  newEntries.contains(where: { $0.id == currentEntryID }) {
            self.currentEntryID = currentEntryID
        } else {
            self.currentEntryID = newEntries.first?.id
        }
    }

    private func isCurrentPlayback(_ token: PlaybackToken) -> Bool {
        activePlaybackGeneration == token.generation
    }

    private func index(offsetBy offset: Int) -> Int? {
        guard !entries.isEmpty else { return nil }
        let currentIndex = entries.firstIndex(where: { $0.id == currentEntryID }) ?? 0
        return (currentIndex + offset).wrappedModulo(entries.count)
    }
}

private extension Int {
    func wrappedModulo(_ modulus: Int) -> Int {
        precondition(modulus > 0)
        let remainder = self % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
