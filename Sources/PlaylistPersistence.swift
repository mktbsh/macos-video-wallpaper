import Foundation

struct PersistedPlaylistEntry: Codable {
    let id: UUID
    let bookmarkData: Data
    let displayName: String
    let useFullVideo: Bool
    let startTime: Double?
    let endTime: Double?

    init(item: PlaylistItem) throws {
        id = item.id
        bookmarkData = try VideoFileValidator.bookmarkData(for: item.url)
        displayName = item.displayName
        useFullVideo = item.useFullVideo
        startTime = item.startTime
        endTime = item.endTime
    }

    var playlistItem: PlaylistItem? {
        guard let url = VideoFileValidator.resolveBookmarkData(bookmarkData) else { return nil }

        return PlaylistItem(
            id: id,
            url: normalizedFileURL(url),
            displayName: displayName,
            useFullVideo: useFullVideo,
            startTime: startTime,
            endTime: endTime
        )
    }
}

struct PersistedPlaylistState: Codable {
    let entries: [PersistedPlaylistEntry]
    let currentItemID: UUID?

    init(entries: [PersistedPlaylistEntry], currentItemID: UUID?) {
        self.entries = entries
        self.currentItemID = currentItemID
    }

    init(store: PlaylistStore) throws {
        entries = try store.items.map(PersistedPlaylistEntry.init(item:))
        currentItemID = store.currentItem?.id
    }

    var playlistStore: PlaylistStore {
        let items = entries.compactMap(\.playlistItem)
        return PlaylistStore(items: items, currentItemID: currentItemID)
    }
}

struct PlaylistPersistence {
    static let storageKey = "playlistState"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PlaylistStore {
        if let data = defaults.data(forKey: Self.storageKey) {
            return loadPersistedState(from: data)
        }

        return loadLegacyStore() ?? PlaylistStore()
    }

    func save(store: PlaylistStore) {
        guard let state = try? PersistedPlaylistState(store: store),
              let data = try? JSONEncoder().encode(state) else { return }

        defaults.set(data, forKey: Self.storageKey)
        VideoFileValidator.clearBookmark(defaults: defaults)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
        VideoFileValidator.clearBookmark(defaults: defaults)
    }

    private func loadPersistedState(from data: Data) -> PlaylistStore {
        guard let state = try? JSONDecoder().decode(PersistedPlaylistState.self, from: data) else {
            defaults.removeObject(forKey: Self.storageKey)
            return loadLegacyStore() ?? PlaylistStore()
        }

        return state.playlistStore
    }

    private func loadLegacyStore() -> PlaylistStore? {
        guard let url = VideoFileValidator.resolveBookmarkedURL(defaults: defaults) else { return nil }

        let store = PlaylistStore(items: [PlaylistItem(url: normalizedFileURL(url))])
        save(store: store)
        return store
    }
}

private func normalizedFileURL(_ url: URL) -> URL {
    let path = url.path
    let normalizedPath = path.hasPrefix("/private/")
        ? String(path.dropFirst("/private".count))
        : path
    return URL(fileURLWithPath: normalizedPath)
}
