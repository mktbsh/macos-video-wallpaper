import Foundation

struct PersistedPlaylistEntry: Codable {
    let id: UUID
    let displayName: String
    let useFullVideo: Bool
    let startTime: Double?
    let endTime: Double?

    init(item: PlaylistItem) {
        id = item.id
        displayName = item.displayName
        useFullVideo = item.useFullVideo
        startTime = item.startTime
        endTime = item.endTime
    }

    func playlistItem(url: URL) -> PlaylistItem {
        PlaylistItem(
            id: id,
            url: normalizedFileURL(url),
            displayName: displayName,
            useFullVideo: useFullVideo,
            startTime: startTime,
            endTime: endTime
        )
    }
}

private struct PersistedPlaylistBookmark: Codable, Equatable {
    let id: UUID
    let filePath: String
    let bookmarkData: Data

    init(item: PlaylistItem) throws {
        let normalizedURL = normalizedFileURL(item.url)
        id = item.id
        filePath = normalizedURL.path
        bookmarkData = try SecurityScopedBookmark.data(for: normalizedURL)
    }

    var resolvedURL: URL? {
        SecurityScopedBookmark.resolve(bookmarkData).map { normalizedFileURL($0.url) }
    }

    func matches(_ item: PlaylistItem) -> Bool {
        id == item.id && filePath == normalizedFileURL(item.url).path
    }
}

private struct LegacyPersistedPlaylistEntry: Codable {
    let id: UUID
    let bookmarkData: Data
    let displayName: String
    let useFullVideo: Bool
    let startTime: Double?
    let endTime: Double?

    var playlistItem: PlaylistItem? {
        guard let resolution = SecurityScopedBookmark.resolve(bookmarkData) else { return nil }

        return PlaylistItem(
            id: id,
            url: normalizedFileURL(resolution.url),
            displayName: displayName,
            useFullVideo: useFullVideo,
            startTime: startTime,
            endTime: endTime
        )
    }
}

private struct LegacyPersistedPlaylistState: Codable {
    let entries: [LegacyPersistedPlaylistEntry]
    let currentItemID: UUID?

    var playlistStore: PlaylistStore {
        let items = entries.compactMap(\.playlistItem)
        return PlaylistStore(items: items, currentItemID: currentItemID)
    }
}

struct PersistedPlaylistState: Codable {
    let entries: [PersistedPlaylistEntry]
    let currentItemID: UUID?

    init(entries: [PersistedPlaylistEntry], currentItemID: UUID?) {
        self.entries = entries
        self.currentItemID = currentItemID
    }

    init(store: PlaylistStore) {
        entries = store.items.map(PersistedPlaylistEntry.init(item:))
        currentItemID = store.currentItem?.id
    }
}

struct PlaylistPersistence {
    static let storageKey = "playlistState"
    static let bookmarkStorageKey = "playlistBookmarks"
    // Legacy 単一壁紙時代のグローバル key。per-display key と同じ文字列だが別概念
    // （こちらは prefix なしの素の key）。migrate / clear の唯一の消費者として保持する。
    private static let legacyBookmarkKey = "videoBookmark"
    private static let legacyPathKey = "videoFilePath"
    private static let emptyBookmarksPayload = Data("[]".utf8)

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
        let state = PersistedPlaylistState(store: store)
        let stateData: Data
        do {
            stateData = try JSONEncoder().encode(state)
        } catch {
            Log.persistence.error("Failed to encode playlist state: \(error.localizedDescription)")
            return
        }
        guard let bookmarkData = encodedBookmarks(for: store) else {
            Log.persistence.error("Failed to encode bookmarks for playlist")
            return
        }

        defaults.set(stateData, forKey: Self.storageKey)
        persistBookmarksIfNeeded(bookmarkData)
        clearLegacyBookmark()
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.bookmarkStorageKey)
        clearLegacyBookmark()
    }

    private func loadPersistedState(from data: Data) -> PlaylistStore {
        if defaults.object(forKey: Self.bookmarkStorageKey) == nil,
           let legacyState = try? JSONDecoder().decode(LegacyPersistedPlaylistState.self, from: data) {
            Log.persistence.info("Migrating legacy playlist state to new format")
            let store = legacyState.playlistStore
            save(store: store)
            return store
        }

        let state: PersistedPlaylistState
        do {
            state = try JSONDecoder().decode(PersistedPlaylistState.self, from: data)
        } catch {
            Log.persistence.error("Failed to decode playlist state: \(error.localizedDescription)")
            defaults.removeObject(forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.bookmarkStorageKey)
            return loadLegacyStore() ?? PlaylistStore()
        }

        let bookmarks = decodedBookmarks(
            from: defaults.data(forKey: Self.bookmarkStorageKey)
        ) ?? []
        return restorePlaylistStore(from: state, bookmarks: bookmarks)
    }

    private func restorePlaylistStore(
        from state: PersistedPlaylistState,
        bookmarks: [PersistedPlaylistBookmark]
    ) -> PlaylistStore {
        let bookmarksByID = Dictionary(
            bookmarks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let items = state.entries.compactMap { entry -> PlaylistItem? in
            guard let bookmark = bookmarksByID[entry.id],
                  let url = bookmark.resolvedURL else { return nil }
            return entry.playlistItem(url: url)
        }

        return PlaylistStore(items: items, currentItemID: state.currentItemID)
    }

    private func loadLegacyStore() -> PlaylistStore? {
        guard let url = resolveLegacyBookmarkedURL() else { return nil }

        let store = PlaylistStore(items: [PlaylistItem(url: normalizedFileURL(url))])
        save(store: store)
        return store
    }

    /// Legacy 単一壁紙の bookmark / path を解決する。
    /// 解決後は save(store:) が legacy key を削除するため、ここでは書き込まない。
    private func resolveLegacyBookmarkedURL() -> URL? {
        if let data = defaults.data(forKey: Self.legacyBookmarkKey) {
            return SecurityScopedBookmark.resolve(data)?.url
        }
        if let path = defaults.string(forKey: Self.legacyPathKey) {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
        return nil
    }

    private func clearLegacyBookmark() {
        defaults.removeObject(forKey: Self.legacyBookmarkKey)
        defaults.removeObject(forKey: Self.legacyPathKey)
    }

    private func encodedBookmarks(for store: PlaylistStore) -> Data? {
        guard !store.items.isEmpty else { return Self.emptyBookmarksPayload }
        let bookmarks: [PersistedPlaylistBookmark]
        do {
            bookmarks = try resolvedBookmarks(for: store)
        } catch {
            Log.persistence.error("Failed to resolve bookmarks: \(error.localizedDescription)")
            return nil
        }
        do {
            return try JSONEncoder().encode(bookmarks)
        } catch {
            Log.persistence.error("Failed to encode bookmarks: \(error.localizedDescription)")
            return nil
        }
    }

    private func resolvedBookmarks(for store: PlaylistStore) throws -> [PersistedPlaylistBookmark] {
        let cached = decodedBookmarks(from: defaults.data(forKey: Self.bookmarkStorageKey)) ?? []
        let cachedBookmarksByID = Dictionary(
            cached.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return try store.items.map { item in
            if let cachedBookmark = cachedBookmarksByID[item.id], cachedBookmark.matches(item) {
                return cachedBookmark
            }
            return try PersistedPlaylistBookmark(item: item)
        }
    }

    private func decodedBookmarks(from data: Data?) -> [PersistedPlaylistBookmark]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([PersistedPlaylistBookmark].self, from: data)
    }

    private func persistBookmarksIfNeeded(_ bookmarkData: Data) {
        let existingData = defaults.data(forKey: Self.bookmarkStorageKey)
        guard existingData != bookmarkData else { return }

        if bookmarkData == Self.emptyBookmarksPayload {
            defaults.removeObject(forKey: Self.bookmarkStorageKey)
        } else {
            defaults.set(bookmarkData, forKey: Self.bookmarkStorageKey)
        }
    }
}

private func normalizedFileURL(_ url: URL) -> URL {
    let path = url.path
    let normalizedPath = path.hasPrefix("/private/")
        ? String(path.dropFirst("/private".count))
        : path
    return URL(fileURLWithPath: normalizedPath)
}
