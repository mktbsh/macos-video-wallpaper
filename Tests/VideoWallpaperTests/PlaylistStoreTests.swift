import Foundation
import Testing
@testable import VideoWallpaper

@Suite(.serialized) struct PlaylistStoreTests {

    @Test func add_urls_sets_first_item_current() {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")

        store.add(urls: [first, second])

        #expect(store.items.map(\.displayName) == ["first.mov", "second.mov"])
        #expect(store.currentItem?.url == first)
        #expect(store.summary?.itemCount == 2)
        #expect(store.summary?.currentDisplayName == "first.mov")
    }

    @Test func next_and_previous_wrap_current_item() {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        store.add(urls: [first, second])

        #expect(store.next() == true)
        #expect(store.currentItem?.url == second)

        #expect(store.previous() == true)
        #expect(store.currentItem?.url == first)
    }

    @Test func delete_current_moves_to_next_item() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        let third = makeURL("third.mov")
        store.add(urls: [first, second, third])

        let firstItemID = try #require(store.items.first?.id)
        #expect(store.delete(id: firstItemID) == true)
        #expect(store.items.map(\.displayName) == ["second.mov", "third.mov"])
        #expect(store.currentItem?.url == second)
    }

    @Test func move_current_item_updates_order_without_losing_selection() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        let third = makeURL("third.mov")
        store.add(urls: [first, second, third])
        #expect(store.next() == true)

        let secondItemID = try #require(
            store.items
                .firstIndex(where: { $0.displayName == "second.mov" })
                .map { store.items[$0].id }
        )
        #expect(store.move(id: secondItemID, by: 1) == true)
        #expect(store.items.map(\.displayName) == ["first.mov", "third.mov", "second.mov"])
        #expect(store.currentItem?.url == second)
    }

    @Test func summary_is_nil_when_playlist_is_empty() {
        let store = PlaylistStore()
        #expect(store.summary == nil)
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}
