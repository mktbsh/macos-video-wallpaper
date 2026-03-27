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

    @Test func add_empty_urls_is_no_op() {
        var store = PlaylistStore()

        store.add(urls: [])

        #expect(store.items.isEmpty)
        #expect(store.currentItem == nil)
        #expect(store.summary == nil)
    }

    @Test func replace_items_uses_explicit_current_item_id() throws {
        let first = PlaylistItem(url: makeURL("first.mov"))
        let second = PlaylistItem(url: makeURL("second.mov"))
        var store = PlaylistStore()

        store.replace(items: [first, second], currentItemID: second.id)

        #expect(store.items == [first, second])
        #expect(store.currentItem?.id == second.id)
        #expect(store.summary?.currentDisplayName == "second.mov")
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

    @Test func completion_advance_returns_false_when_playlist_is_empty() {
        var store = PlaylistStore()
        var otherStore = PlaylistStore()
        otherStore.add(urls: [makeURL("first.mov")])
        let token = otherStore.beginPlayback()

        #expect(store.advanceAfterPlaybackCompletion(using: token) == false)
        #expect(store.currentItem == nil)
    }

    @Test func set_current_changes_current_item_without_playback_token() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        store.add(urls: [first, second])

        let secondID = try #require(store.items.last?.id)

        #expect(store.setCurrent(id: secondID) == true)
        #expect(store.currentItem?.url == second)
    }

    @Test func completion_advance_uses_current_playback_token() {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        store.add(urls: [first, second])

        let staleToken = store.beginPlayback()
        let currentToken = store.beginPlayback()

        #expect(store.advanceAfterPlaybackCompletion(using: staleToken) == false)
        #expect(store.currentItem?.url == first)

        #expect(store.advanceAfterPlaybackCompletion(using: currentToken) == true)
        #expect(store.currentItem?.url == second)
    }

    @Test func single_item_completion_advance_keeps_current_item() {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        store.add(urls: [first])

        let token = store.beginPlayback()

        #expect(store.advanceAfterPlaybackCompletion(using: token) == true)
        #expect(store.currentItem?.url == first)
    }

    @Test func clear_removes_all_items_and_summary() {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov"), makeURL("second.mov")])

        store.clear()

        #expect(store.items.isEmpty)
        #expect(store.currentItem == nil)
        #expect(store.summary == nil)
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

    @Test func delete_non_current_keeps_current_item() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        let third = makeURL("third.mov")
        store.add(urls: [first, second, third])
        #expect(store.next() == true)

        let firstItemID = try #require(store.items.first?.id)
        #expect(store.delete(id: firstItemID) == true)
        #expect(store.currentItem?.url == second)
        #expect(store.items.map(\.displayName) == ["second.mov", "third.mov"])
    }

    @Test func delete_last_current_moves_to_previous_item() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        let third = makeURL("third.mov")
        store.add(urls: [first, second, third])
        #expect(store.previous() == true)

        let thirdItemID = try #require(store.currentItem?.id)
        #expect(store.delete(id: thirdItemID) == true)
        #expect(store.currentItem?.url == second)
        #expect(store.items.map(\.displayName) == ["first.mov", "second.mov"])
    }

    @Test func delete_invalid_id_is_no_op() {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov"), makeURL("second.mov")])
        let originalItems = store.items
        let originalCurrentID = store.currentItem?.id

        #expect(store.delete(id: UUID()) == false)
        #expect(store.items == originalItems)
        #expect(store.currentItem?.id == originalCurrentID)
    }

    @Test func delete_last_remaining_item_clears_store() throws {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov")])

        let currentItemID = try #require(store.currentItem?.id)
        #expect(store.delete(id: currentItemID) == true)
        #expect(store.items.isEmpty)
        #expect(store.currentItem == nil)
        #expect(store.summary == nil)
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

    @Test func move_non_current_item_keeps_current_selection() throws {
        var store = PlaylistStore()
        let first = makeURL("first.mov")
        let second = makeURL("second.mov")
        let third = makeURL("third.mov")
        store.add(urls: [first, second, third])
        #expect(store.next() == true)

        let firstItemID = try #require(store.items.first?.id)
        #expect(store.move(id: firstItemID, by: 1) == true)
        #expect(store.items.map(\.displayName) == ["second.mov", "first.mov", "third.mov"])
        #expect(store.currentItem?.url == second)
    }

    @Test func move_invalid_id_and_out_of_bounds_are_no_op() throws {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov"), makeURL("second.mov")])
        let originalItems = store.items
        let firstItemID = try #require(store.items.first?.id)

        #expect(store.move(id: UUID(), by: 1) == false)
        #expect(store.move(id: firstItemID, by: -1) == false)
        #expect(store.items == originalItems)
    }

    @Test func update_display_name_updates_summary() throws {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov"), makeURL("second.mov")])
        let currentID = try #require(store.currentItem?.id)

        #expect(store.updateDisplayName(id: currentID, displayName: "Intro Clip") == true)
        #expect(store.currentItem?.displayName == "Intro Clip")
        #expect(store.summary?.currentDisplayName == "Intro Clip")
    }

    @Test func update_display_name_to_empty_falls_back_to_filename_in_summary() throws {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov")])
        let currentID = try #require(store.currentItem?.id)

        #expect(store.updateDisplayName(id: currentID, displayName: "Custom Name") == true)
        #expect(store.updateDisplayName(id: currentID, displayName: "") == true)
        #expect(store.currentItem?.effectiveDisplayName == "first.mov")
        #expect(store.summary?.currentDisplayName == "first.mov")
    }

    @Test func update_use_full_video_clears_saved_time_range() throws {
        let item = PlaylistItem(
            url: makeURL("first.mov"),
            useFullVideo: false,
            startTime: 1,
            endTime: 5
        )
        var store = PlaylistStore(items: [item], currentItemID: item.id)

        #expect(store.currentItem?.playbackTimeRange != nil)
        #expect(store.updateUseFullVideo(id: item.id, useFullVideo: true) == true)
        #expect(store.currentItem?.useFullVideo == true)
        #expect(store.currentItem?.startTime == nil)
        #expect(store.currentItem?.endTime == nil)
        #expect(store.currentItem?.playbackTimeRange == nil)
    }

    @Test func update_methods_return_false_for_missing_item() {
        var store = PlaylistStore()
        store.add(urls: [makeURL("first.mov")])
        let originalItems = store.items

        #expect(store.updateDisplayName(id: UUID(), displayName: "Missing") == false)
        #expect(store.updateUseFullVideo(id: UUID(), useFullVideo: false) == false)
        #expect(store.updateStartTime(id: UUID(), startTime: 1) == false)
        #expect(store.updateEndTime(id: UUID(), endTime: 2) == false)
        #expect(store.items == originalItems)
    }

    @Test func summary_is_nil_when_playlist_is_empty() {
        let store = PlaylistStore()
        #expect(store.summary == nil)
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}
