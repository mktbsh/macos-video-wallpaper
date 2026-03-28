import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized)
struct PlaylistPersistenceTests {

    @Test func save_and_restore_playlist_state() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let first = try context.makeVideoURL("first.mov")
        let second = try context.makeVideoURL("second.mov")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let secondItem = PlaylistItem(
            url: second,
            displayName: "Second",
            useFullVideo: false,
            startTime: 1.5,
            endTime: 3.0
        )
        let store = PlaylistStore(
            items: [PlaylistItem(url: first), secondItem],
            currentItemID: secondItem.id
        )

        context.persistence.save(store: store)
        let restored = context.persistence.load()

        #expect(restored.items.count == 2)
        #expect(restored.items[1].displayName == "Second")
        #expect(restored.items[1].useFullVideo == false)
        #expect(restored.items[1].startTime == 1.5)
        #expect(restored.items[1].endTime == 3.0)
        #expect(restored.currentItem?.id == secondItem.id)
    }

    @Test func restore_filters_out_invalid_bookmarks() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let first = try context.makeVideoURL("first.mov")
        let second = try context.makeVideoURL("second.mov")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let firstItem = PlaylistItem(url: first)
        let secondItem = PlaylistItem(url: second)
        let store = PlaylistStore(items: [firstItem, secondItem], currentItemID: secondItem.id)

        context.persistence.save(store: store)
        try FileManager.default.removeItem(at: second)

        let restored = context.persistence.load()

        #expect(restored.items.count == 1)
        #expect(restored.items.first?.url == first)
        #expect(restored.currentItem?.url == first)
    }

    @Test func restore_falls_back_to_first_item_when_current_id_is_missing() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let first = try context.makeVideoURL("first.mov")
        let second = try context.makeVideoURL("second.mov")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let firstItem = PlaylistItem(url: first)
        let secondItem = PlaylistItem(url: second)
        let originalStore = PlaylistStore(
            items: [firstItem, secondItem],
            currentItemID: nil
        )
        context.persistence.save(store: originalStore)

        let state = PersistedPlaylistState(
            entries: [
                PersistedPlaylistEntry(item: firstItem),
                PersistedPlaylistEntry(item: secondItem)
            ],
            currentItemID: UUID()
        )
        let data = try JSONEncoder().encode(state)
        context.defaults.set(data, forKey: PlaylistPersistence.storageKey)

        let restored = context.persistence.load()

        #expect(restored.items.count == 2)
        #expect(restored.currentItem?.url == first)
    }

    @Test func migrate_legacy_single_bookmark_to_playlist_state() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = try context.makeVideoURL("legacy.mov")
        defer { try? FileManager.default.removeItem(at: url) }
        VideoFileValidator.saveBookmark(for: url, defaults: context.defaults)

        let restored = context.persistence.load()
        let restoredAgain = context.persistence.load()

        #expect(restored.items.count == 1)
        #expect(restored.currentItem?.url == url)
        #expect(restoredAgain.items.count == 1)
        #expect(restoredAgain.currentItem?.url == url)
        #expect(context.defaults.data(forKey: PlaylistPersistence.storageKey) != nil)
        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    @Test func corrupt_playlist_state_falls_back_to_legacy_once() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = try context.makeVideoURL("legacy.mov")
        defer { try? FileManager.default.removeItem(at: url) }
        context.defaults.set(Data("bad".utf8), forKey: PlaylistPersistence.storageKey)
        VideoFileValidator.saveBookmark(for: url, defaults: context.defaults)

        let restored = context.persistence.load()
        let restoredAgain = context.persistence.load()

        #expect(restored.items.count == 1)
        #expect(restored.currentItem?.url == url)
        #expect(context.defaults.data(forKey: PlaylistPersistence.storageKey) != Data("bad".utf8))
        #expect(restoredAgain.items.count == 1)
        #expect(restoredAgain.currentItem?.url == url)
        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    @Test func clear_removes_playlist_state_and_legacy_bookmark() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = try context.makeVideoURL("legacy.mov")
        defer { try? FileManager.default.removeItem(at: url) }
        context.defaults.set(Data("playlist".utf8), forKey: PlaylistPersistence.storageKey)
        VideoFileValidator.saveBookmark(for: url, defaults: context.defaults)

        context.persistence.clear()

        #expect(context.defaults.data(forKey: PlaylistPersistence.storageKey) == nil)
        #expect(context.defaults.data(forKey: bookmarkKey) == nil)
    }

    @Test func save_reuses_bookmark_payload_when_only_current_item_changes() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let first = try context.makeVideoURL("first.mov")
        let second = try context.makeVideoURL("second.mov")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let firstItem = PlaylistItem(url: first)
        let secondItem = PlaylistItem(url: second)
        let initialStore = PlaylistStore(items: [firstItem, secondItem], currentItemID: firstItem.id)

        context.persistence.save(store: initialStore)
        let initialBookmarkData = try #require(
            context.defaults.data(forKey: playlistBookmarksKey)
        )
        let initialBookmarks = try #require(decodeBookmarks(initialBookmarkData))

        let updatedStore = PlaylistStore(items: [firstItem, secondItem], currentItemID: secondItem.id)
        context.persistence.save(store: updatedStore)
        let updatedBookmarkData = try #require(
            context.defaults.data(forKey: playlistBookmarksKey)
        )
        let updatedBookmarks = try #require(decodeBookmarks(updatedBookmarkData))

        #expect(updatedBookmarks == initialBookmarks)
    }

    @Test func load_migrates_legacy_embedded_bookmarks_to_separate_bookmark_store() throws {
        let context = TestContext()
        defer { context.cleanup() }
        let url = try context.makeVideoURL("legacy.mov")
        defer { try? FileManager.default.removeItem(at: url) }

        let item = PlaylistItem(url: url, displayName: "Legacy")
        let legacyState = try LegacyPersistedPlaylistState(
            entries: [LegacyPersistedPlaylistEntry(item: item)],
            currentItemID: item.id
        )
        let legacyData = try JSONEncoder().encode(legacyState)
        context.defaults.set(legacyData, forKey: PlaylistPersistence.storageKey)

        let restored = context.persistence.load()

        #expect(restored.items.count == 1)
        #expect(restored.currentItem?.id == item.id)
        #expect(restored.currentItem?.displayName == "Legacy")
        #expect(context.defaults.data(forKey: playlistBookmarksKey) != nil)
    }

    private let bookmarkKey = "videoBookmark"
    private let playlistBookmarksKey = "playlistBookmarks"

    private func decodeBookmarks(_ data: Data) -> [PersistedBookmarkPayload]? {
        try? JSONDecoder().decode([PersistedBookmarkPayload].self, from: data)
    }
}

private struct TestContext {
    let suiteName = "PlaylistPersistenceTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let persistence: PlaylistPersistence

    init() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults
        self.persistence = PlaylistPersistence(defaults: defaults)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeVideoURL(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName)-\(name)")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }
}

private struct LegacyPersistedPlaylistEntry: Codable {
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
}

private struct LegacyPersistedPlaylistState: Codable {
    let entries: [LegacyPersistedPlaylistEntry]
    let currentItemID: UUID?
}

private struct PersistedBookmarkPayload: Codable, Equatable {
    let id: UUID
    let filePath: String
    let bookmarkData: Data
}
