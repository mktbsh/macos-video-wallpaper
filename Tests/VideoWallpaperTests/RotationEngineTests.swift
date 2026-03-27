import Testing
@testable import VideoWallpaper

@Suite struct RotationEngineTests {

    private struct Entry: Identifiable, Equatable {
        let id: String
    }

    @Test func stale_token_is_rejected_for_playback_completion() {
        let entries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        let staleToken = engine.beginPlayback()
        let currentToken = engine.beginPlayback()

        #expect(engine.advanceAfterPlaybackCompletion(using: staleToken) == false)
        #expect(engine.currentEntryID == entries[0].id)

        #expect(engine.advanceAfterPlaybackCompletion(using: currentToken) == true)
        #expect(engine.currentEntryID == entries[1].id)
    }

    @Test func completion_advance_wraps_to_first_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[2].id)

        let token = engine.beginPlayback()

        #expect(engine.advanceAfterPlaybackCompletion(using: token) == true)
        #expect(engine.currentEntryID == entries[0].id)
    }

    @Test func manual_next_wraps_to_first_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[2].id)

        #expect(engine.next() == true)
        #expect(engine.currentEntryID == entries[0].id)
    }

    @Test func manual_previous_wraps_to_last_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        #expect(engine.previous() == true)
        #expect(engine.currentEntryID == entries[2].id)
    }

    @Test func next_and_previous_return_false_when_engine_is_empty() {
        var engine = RotationEngine<Entry>()

        #expect(engine.next() == false)
        #expect(engine.previous() == false)
        #expect(engine.currentEntryID == nil)
    }

    @Test func set_current_returns_false_for_missing_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        #expect(engine.setCurrent(id: "missing") == false)
        #expect(engine.currentEntryID == entries[0].id)
    }

    @Test func advance_after_completion_returns_false_without_active_playback() {
        let entries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)
        var otherEngine = RotationEngine(entries: entries, currentEntryID: entries[0].id)
        let token = otherEngine.beginPlayback()

        #expect(engine.advanceAfterPlaybackCompletion(using: token) == false)
        #expect(engine.currentEntryID == entries[0].id)
    }

    @Test func replace_updates_entries_and_current_entry() {
        let originalEntries = [Entry(id: "a"), Entry(id: "b")]
        let replacementEntries = [Entry(id: "x"), Entry(id: "y"), Entry(id: "z")]
        var engine = RotationEngine(entries: originalEntries, currentEntryID: originalEntries[0].id)

        let token = engine.beginPlayback()
        engine.replace(entries: replacementEntries, currentEntryID: replacementEntries[1].id)

        #expect(engine.currentEntryID == replacementEntries[1].id)
        #expect(engine.advanceAfterPlaybackCompletion(using: token) == true)
        #expect(engine.currentEntryID == replacementEntries[2].id)
    }

    @Test func replace_keeps_existing_current_when_requested_current_is_missing() {
        let originalEntries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: originalEntries, currentEntryID: entriesID("b"))

        let replacementEntries = [Entry(id: "b"), Entry(id: "c"), Entry(id: "d")]
        engine.replace(entries: replacementEntries, currentEntryID: "missing")

        #expect(engine.currentEntryID == "b")
    }

    @Test func replace_falls_back_to_first_when_requested_and_existing_current_are_missing() {
        let originalEntries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: originalEntries, currentEntryID: entriesID("b"))

        let replacementEntries = [Entry(id: "x"), Entry(id: "y")]
        engine.replace(entries: replacementEntries, currentEntryID: "missing")

        #expect(engine.currentEntryID == replacementEntries[0].id)
    }

    @Test func replace_to_empty_clears_current_and_rejects_existing_token() {
        let entries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)
        let token = engine.beginPlayback()

        engine.replace(entries: [], currentEntryID: nil)

        #expect(engine.currentEntryID == nil)
        #expect(engine.advanceAfterPlaybackCompletion(using: token) == false)
    }

    @Test func single_entry_completion_advance_keeps_current_entry() {
        let entries = [Entry(id: "a")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        let token = engine.beginPlayback()

        #expect(engine.advanceAfterPlaybackCompletion(using: token) == true)
        #expect(engine.currentEntryID == entries[0].id)
    }

    private func entriesID(_ value: String) -> String { value }
}
