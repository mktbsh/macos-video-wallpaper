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
        let state = try PersistedPlaylistState(
            entries: [
                PersistedPlaylistEntry(item: PlaylistItem(url: first)),
                PersistedPlaylistEntry(item: PlaylistItem(url: second))
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

    private let bookmarkKey = "videoBookmark"
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
