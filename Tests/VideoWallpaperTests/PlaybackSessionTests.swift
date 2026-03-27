import Foundation
import Testing
@testable import VideoWallpaper

@Suite struct PlaybackSessionTests {

    @Test func begin_playback_returns_nil_for_empty_playlist_and_clears_current_token() {
        var store = PlaylistStore()
        var session = PlaybackSession()

        #expect(session.beginPlayback(using: &store) == nil)
        #expect(session.currentToken == nil)
    }

    @Test func begin_playback_returns_current_item_and_fresh_token() throws {
        var store = makeStore(["first.mov", "second.mov"])
        var session = PlaybackSession()

        let maybePlayback = session.beginPlayback(using: &store)
        let playback = try #require(maybePlayback)

        #expect(playback.item.url.lastPathComponent == "first.mov")
        #expect(session.currentToken == playback.token)
    }

    @Test func begin_playback_twice_mints_distinct_tokens() throws {
        var store = makeStore(["first.mov"])
        var session = PlaybackSession()

        let firstMaybePlayback = session.beginPlayback(using: &store)
        let firstPlayback = try #require(firstMaybePlayback)
        let secondMaybePlayback = session.beginPlayback(using: &store)
        let secondPlayback = try #require(secondMaybePlayback)

        #expect(firstPlayback.token != secondPlayback.token)
        #expect(secondPlayback.item.id == firstPlayback.item.id)
        #expect(session.currentToken == secondPlayback.token)
    }

    @Test func begin_playback_after_store_is_cleared_returns_nil_and_resets_current_token() throws {
        var store = makeStore(["first.mov"])
        var session = PlaybackSession()
        let firstMaybePlayback = session.beginPlayback(using: &store)
        _ = try #require(firstMaybePlayback)

        store.clear()

        #expect(session.beginPlayback(using: &store) == nil)
        #expect(session.currentToken == nil)
    }

    @Test func consume_completion_ignores_stale_token_without_advancing() throws {
        var store = makeStore(["first.mov", "second.mov"])
        var session = PlaybackSession()
        let staleMaybePlayback = session.beginPlayback(using: &store)
        let stalePlayback = try #require(staleMaybePlayback)
        let currentMaybePlayback = session.beginPlayback(using: &store)
        let currentPlayback = try #require(currentMaybePlayback)

        #expect(
            session.consume(
                PlaybackCompletion(itemID: stalePlayback.item.id, token: stalePlayback.token),
                using: &store
            ) == false
        )
        #expect(store.currentItem?.id == currentPlayback.item.id)
        #expect(session.currentToken == currentPlayback.token)
    }

    @Test func consume_completion_advances_playlist_and_clears_current_token() throws {
        var store = makeStore(["first.mov", "second.mov"])
        var session = PlaybackSession()
        let maybePlayback = session.beginPlayback(using: &store)
        let currentPlayback = try #require(maybePlayback)

        #expect(
            session.consume(
                PlaybackCompletion(itemID: currentPlayback.item.id, token: currentPlayback.token),
                using: &store
            ) == true
        )
        #expect(store.currentItem?.url.lastPathComponent == "second.mov")
        #expect(session.currentToken == nil)
    }

    @Test func duplicate_completion_is_ignored_after_first_consumption() throws {
        var store = makeStore(["first.mov", "second.mov", "third.mov"])
        var session = PlaybackSession()
        let maybePlayback = session.beginPlayback(using: &store)
        let currentPlayback = try #require(maybePlayback)
        let completion = PlaybackCompletion(itemID: currentPlayback.item.id, token: currentPlayback.token)

        #expect(session.consume(completion, using: &store) == true)
        #expect(store.currentItem?.url.lastPathComponent == "second.mov")

        #expect(session.consume(completion, using: &store) == false)
        #expect(store.currentItem?.url.lastPathComponent == "second.mov")
    }

    @Test func consumed_completion_wraps_to_first_item() throws {
        var store = makeStore(["first.mov", "second.mov", "third.mov"])
        _ = store.previous()
        var session = PlaybackSession()
        let maybePlayback = session.beginPlayback(using: &store)
        let currentPlayback = try #require(maybePlayback)

        #expect(
            session.consume(
                PlaybackCompletion(itemID: currentPlayback.item.id, token: currentPlayback.token),
                using: &store
            ) == true
        )
        #expect(store.currentItem?.url.lastPathComponent == "first.mov")
    }

    @Test func single_item_completion_keeps_same_item_and_requires_new_token_for_restart() throws {
        var store = makeStore(["first.mov"])
        var session = PlaybackSession()
        let firstMaybePlayback = session.beginPlayback(using: &store)
        let firstPlayback = try #require(firstMaybePlayback)

        #expect(
            session.consume(
                PlaybackCompletion(itemID: firstPlayback.item.id, token: firstPlayback.token),
                using: &store
            ) == true
        )
        #expect(store.currentItem?.id == firstPlayback.item.id)
        #expect(session.currentToken == nil)

        let secondMaybePlayback = session.beginPlayback(using: &store)
        let secondPlayback = try #require(secondMaybePlayback)
        #expect(secondPlayback.item.id == firstPlayback.item.id)
        #expect(secondPlayback.token != firstPlayback.token)
    }

    @Test func manual_playlist_change_followed_by_begin_invalidates_old_completion() throws {
        var store = makeStore(["first.mov", "second.mov", "third.mov"])
        var session = PlaybackSession()
        let firstMaybePlayback = session.beginPlayback(using: &store)
        let firstPlayback = try #require(firstMaybePlayback)

        #expect(store.next() == true)
        let secondMaybePlayback = session.beginPlayback(using: &store)
        let secondPlayback = try #require(secondMaybePlayback)

        #expect(
            session.consume(
                PlaybackCompletion(itemID: firstPlayback.item.id, token: firstPlayback.token),
                using: &store
            ) == false
        )
        #expect(store.currentItem?.id == secondPlayback.item.id)
        #expect(session.currentToken == secondPlayback.token)
    }

    private func makeStore(_ names: [String]) -> PlaylistStore {
        var store = PlaylistStore()
        store.add(urls: names.map { URL(fileURLWithPath: "/tmp/\($0)") })
        return store
    }
}
