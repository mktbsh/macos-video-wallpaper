import Testing
@testable import VideoWallpaper

@Suite struct RotationEngineTests {

    private struct Entry: Identifiable, Equatable {
        let id: String
    }

    @Test func stale_token_is_rejected() {
        let entries = [Entry(id: "a"), Entry(id: "b")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        let staleToken = engine.beginPlayback()
        let currentToken = engine.beginPlayback()

        #expect(engine.next(using: staleToken) == false)
        #expect(engine.currentEntryID == entries[0].id)

        #expect(engine.next(using: currentToken) == true)
        #expect(engine.currentEntryID == entries[1].id)
    }

    @Test func next_wraps_to_first_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[2].id)

        let token = engine.beginPlayback()

        #expect(engine.next(using: token) == true)
        #expect(engine.currentEntryID == entries[0].id)
    }

    @Test func previous_wraps_to_last_entry() {
        let entries = [Entry(id: "a"), Entry(id: "b"), Entry(id: "c")]
        var engine = RotationEngine(entries: entries, currentEntryID: entries[0].id)

        let token = engine.beginPlayback()

        #expect(engine.previous(using: token) == true)
        #expect(engine.currentEntryID == entries[2].id)
    }

    @Test func replace_updates_entries_and_current_entry() {
        let originalEntries = [Entry(id: "a"), Entry(id: "b")]
        let replacementEntries = [Entry(id: "x"), Entry(id: "y"), Entry(id: "z")]
        var engine = RotationEngine(entries: originalEntries, currentEntryID: originalEntries[0].id)

        let token = engine.beginPlayback()
        engine.replace(entries: replacementEntries, currentEntryID: replacementEntries[1].id)

        #expect(engine.currentEntryID == replacementEntries[1].id)
        #expect(engine.next(using: token) == true)
        #expect(engine.currentEntryID == replacementEntries[2].id)
    }
}
