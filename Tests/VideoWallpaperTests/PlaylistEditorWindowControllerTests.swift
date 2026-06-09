import Foundation
import Testing
@testable import VideoWallpaper

@Suite @MainActor
struct PlaylistEditorWindowControllerTests {

    private struct AppliedRange {
        let itemID: PlaylistItem.ID
        let start: Double?
        let end: Double?
    }

    // MARK: - PlaylistEditorWindowController.reload

    @Test func selected_item_returns_item_matching_selection() {
        let first = PlaylistItem(url: makeEditorURL("first.mov"))
        let second = PlaylistItem(url: makeEditorURL("second.mov"))
        let state = PlaylistEditorState()
        state.items = [first, second]
        state.selection = second.id

        #expect(state.selectedItem == second)
    }

    @Test func selected_item_returns_nil_when_selection_is_nil() {
        let state = PlaylistEditorState()
        state.items = [PlaylistItem(url: makeEditorURL("clip.mov"))]
        state.selection = nil

        #expect(state.selectedItem == nil)
    }

    @Test func reload_sets_items_and_current_item_id() {
        let controller = PlaylistEditorWindowController()
        let item = PlaylistItem(url: makeEditorURL("clip.mov"))

        controller.reload(items: [item], currentItemID: item.id)

        #expect(controller.state.items == [item])
        #expect(controller.state.currentItemID == item.id)
    }

    @Test func reload_with_empty_items_clears_selection_and_validation() {
        let controller = PlaylistEditorWindowController()
        let item = PlaylistItem(url: makeEditorURL("clip.mov"))
        controller.reload(items: [item], currentItemID: item.id)
        controller.state.validationMessage = "stale"

        controller.reload(items: [], currentItemID: nil)

        #expect(controller.state.items.isEmpty)
        #expect(controller.state.selection == nil)
        #expect(controller.state.validationMessage == nil)
    }

    @Test func reload_preserves_valid_selection_without_resetting_validation() {
        let controller = PlaylistEditorWindowController()
        let first = PlaylistItem(url: makeEditorURL("first.mov"))
        let second = PlaylistItem(url: makeEditorURL("second.mov"))
        controller.reload(items: [first, second], currentItemID: first.id)
        controller.state.selection = second.id
        controller.state.validationMessage = "some error"

        controller.reload(items: [first, second], currentItemID: first.id)

        #expect(controller.state.selection == second.id)
        #expect(controller.state.validationMessage == "some error")
    }

    @Test func reload_sets_selection_to_current_item_when_selection_is_nil() {
        let controller = PlaylistEditorWindowController()
        let first = PlaylistItem(url: makeEditorURL("first.mov"))
        let second = PlaylistItem(url: makeEditorURL("second.mov"))

        controller.reload(items: [first, second], currentItemID: second.id)

        #expect(controller.state.selection == second.id)
        #expect(controller.state.validationMessage == nil)
    }

    @Test func reload_with_nil_current_id_and_nil_selection_sets_selection_to_first_item() {
        let controller = PlaylistEditorWindowController()
        let first = PlaylistItem(url: makeEditorURL("first.mov"))
        let second = PlaylistItem(url: makeEditorURL("second.mov"))

        controller.reload(items: [first, second], currentItemID: nil)

        #expect(controller.state.selection == first.id)
        #expect(controller.state.validationMessage == nil)
    }

    @Test func reload_resets_selection_to_current_when_selected_item_is_removed() {
        let controller = PlaylistEditorWindowController()
        let first = PlaylistItem(url: makeEditorURL("first.mov"))
        let second = PlaylistItem(url: makeEditorURL("second.mov"))
        controller.reload(items: [first, second], currentItemID: first.id)
        controller.state.selection = second.id
        controller.state.validationMessage = "stale error"

        controller.reload(items: [first], currentItemID: first.id)

        #expect(controller.state.selection == first.id)
        #expect(controller.state.validationMessage == nil)
    }

    // MARK: - PlaylistEditorTimeRangeCommitter

    @Test func commit_when_use_full_video_applies_nil_range() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []
        var capturedMessages: [String?] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "1.0",
            endText: "5.0",
            useFullVideo: true,
            validateTimeRange: nil,
            setValidationMessage: { capturedMessages.append($0) },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.count == 1)
        #expect(appliedRanges.first?.start == nil)
        #expect(appliedRanges.first?.end == nil)
        #expect(capturedMessages == [nil])
    }

    @Test func commit_with_unparseable_text_does_not_apply() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "abc",
            endText: "3.0",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.isEmpty)
    }

    @Test func commit_with_validation_error_does_not_apply() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []
        var capturedMessage: String?

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "5.0",
            endText: "3.0",
            useFullVideo: false,
            validateTimeRange: { _, _, _, _ in "End must be after start" },
            setValidationMessage: { capturedMessage = $0 },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.isEmpty)
        #expect(capturedMessage == "End must be after start")
    }

    @Test func commit_with_negative_time_does_not_apply() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "-1.0",
            endText: "5.0",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.isEmpty)
    }

    @Test func commit_with_infinite_time_does_not_apply() {
        // "inf" parses as Double.infinity, which is caught by the isFinite check
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "inf",
            endText: "5.0",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.isEmpty)
    }

    @Test func commit_with_empty_text_does_not_apply() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "",
            endText: "",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.isEmpty)
    }

    @Test func commit_with_unparseable_text_clears_validation_message() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var capturedMessages: [String?] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "abc",
            endText: "3.0",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { capturedMessages.append($0) },
            applyTimeRange: { _, _, _ in }
        ))

        #expect(capturedMessages == [nil])
    }

    @Test func commit_without_validator_applies_valid_time_range() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "2.0",
            endText: "6.0",
            useFullVideo: false,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.count == 1)
        #expect(appliedRanges.first?.start == 2.0)
        #expect(appliedRanges.first?.end == 6.0)
    }

    @Test func commit_time_range_emits_single_batched_update() {
        let item = PlaylistItem(url: makeEditorURL("sample.mov"))
        var appliedRanges: [AppliedRange] = []
        var validationMessages: [String?] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "1.5",
            endText: "3.0",
            useFullVideo: false,
            validateTimeRange: { _, _, _, _ in nil as String? },
            setValidationMessage: { validationMessages.append($0) },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.count == 1)
        #expect(appliedRanges.first?.itemID == item.id)
        #expect(appliedRanges.first?.start == 1.5)
        #expect(appliedRanges.first?.end == 3.0)
        #expect(validationMessages == [nil])
    }
}

private func makeEditorURL(_ name: String) -> URL {
    URL(fileURLWithPath: "/tmp/\(name)")
}
