import Foundation
import Testing
@testable import VideoWallpaper

@Suite struct PlaylistStoreMutationTests {

    @Test func update_display_name_updates_summary() throws {
        var store = PlaylistStore()
        store.add(urls: [makeMutURL("first.mov"), makeMutURL("second.mov")])
        let currentID = try #require(store.currentItem?.id)

        #expect(store.updateDisplayName(id: currentID, displayName: "Intro Clip") == true)
        #expect(store.currentItem?.displayName == "Intro Clip")
        #expect(store.summary?.currentDisplayName == "Intro Clip")
    }

    @Test func update_display_name_to_empty_falls_back_to_filename_in_summary() throws {
        var store = PlaylistStore()
        store.add(urls: [makeMutURL("first.mov")])
        let currentID = try #require(store.currentItem?.id)

        #expect(store.updateDisplayName(id: currentID, displayName: "Custom Name") == true)
        #expect(store.updateDisplayName(id: currentID, displayName: "") == true)
        #expect(store.currentItem?.displayName == "first.mov")
        #expect(store.summary?.currentDisplayName == "first.mov")
    }

    @Test func update_use_full_video_clears_saved_time_range() throws {
        let item = PlaylistItem(
            url: makeMutURL("first.mov"),
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

    @Test func update_use_full_video_to_false_preserves_existing_time_range() throws {
        let item = PlaylistItem(
            url: makeMutURL("clip.mov"),
            useFullVideo: false,
            startTime: 2.0,
            endTime: 7.0
        )
        var store = PlaylistStore(items: [item], currentItemID: item.id)

        #expect(store.updateUseFullVideo(id: item.id, useFullVideo: false) == true)
        #expect(store.currentItem?.startTime == 2.0)
        #expect(store.currentItem?.endTime == 7.0)
    }

    @Test func update_use_full_video_to_false_on_fresh_item_leaves_times_nil() {
        let item = PlaylistItem(url: makeMutURL("clip.mov"))
        var store = PlaylistStore(items: [item], currentItemID: item.id)

        #expect(store.updateUseFullVideo(id: item.id, useFullVideo: false) == true)
        #expect(store.currentItem?.useFullVideo == false)
        #expect(store.currentItem?.startTime == nil)
        #expect(store.currentItem?.endTime == nil)
        #expect(store.currentItem?.playbackTimeRange == nil)
    }

    @Test func update_time_range_sets_both_start_and_end_atomically() throws {
        let item = PlaylistItem(url: makeMutURL("clip.mov"), useFullVideo: false)
        var store = PlaylistStore(items: [item], currentItemID: item.id)

        #expect(store.updateTimeRange(id: item.id, startTime: 2.0, endTime: 8.0) == true)
        #expect(store.currentItem?.startTime == 2.0)
        #expect(store.currentItem?.endTime == 8.0)
        #expect(store.currentItem?.playbackTimeRange != nil)
    }

    @Test func update_time_range_with_nil_clears_existing_range() throws {
        let item = PlaylistItem(
            url: makeMutURL("trim.mov"),
            useFullVideo: false,
            startTime: 1.0,
            endTime: 6.0
        )
        var store = PlaylistStore(items: [item], currentItemID: item.id)
        #expect(store.currentItem?.playbackTimeRange != nil)

        #expect(store.updateTimeRange(id: item.id, startTime: nil, endTime: nil) == true)
        #expect(store.currentItem?.startTime == nil)
        #expect(store.currentItem?.endTime == nil)
        #expect(store.currentItem?.playbackTimeRange == nil)
    }

    @Test func update_methods_return_false_for_missing_item() {
        var store = PlaylistStore()
        store.add(urls: [makeMutURL("first.mov")])
        let originalItems = store.items

        #expect(store.updateDisplayName(id: UUID(), displayName: "Missing") == false)
        #expect(store.updateUseFullVideo(id: UUID(), useFullVideo: false) == false)
        #expect(store.updateTimeRange(id: UUID(), startTime: 1, endTime: 2) == false)
        #expect(store.items == originalItems)
    }

    @Test func add_urls_to_non_empty_store_preserves_current_item() {
        var store = PlaylistStore()
        store.add(urls: [makeMutURL("first.mov")])
        let originalCurrentID = store.currentItem?.id

        store.add(urls: [makeMutURL("second.mov"), makeMutURL("third.mov")])

        #expect(store.items.count == 3)
        #expect(store.currentItem?.id == originalCurrentID)
        #expect(store.currentItem?.url == makeMutURL("first.mov"))
    }

    @Test func add_urls_preserves_non_first_current_item() {
        var store = PlaylistStore()
        store.add(urls: [makeMutURL("first.mov"), makeMutURL("second.mov")])
        _ = store.next()
        let midCurrentID = store.currentItem?.id

        store.add(urls: [makeMutURL("third.mov")])

        #expect(store.items.count == 3)
        #expect(store.currentItem?.id == midCurrentID)
        #expect(store.currentItem?.url == makeMutURL("second.mov"))
    }

    @Test func summary_is_nil_when_playlist_is_empty() {
        let store = PlaylistStore()
        #expect(store.summary == nil)
    }
}

private func makeMutURL(_ name: String) -> URL {
    URL(fileURLWithPath: "/tmp/\(name)")
}
