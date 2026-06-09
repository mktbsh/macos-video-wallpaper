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

    @Test func commit_when_use_full_video_applies_nil_range() {
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
        var appliedRanges: [AppliedRange] = []

        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: "1.0",
            endText: "5.0",
            useFullVideo: true,
            validateTimeRange: nil,
            setValidationMessage: { _ in },
            applyTimeRange: { itemID, start, end in
                appliedRanges.append(AppliedRange(itemID: itemID, start: start, end: end))
            }
        ))

        #expect(appliedRanges.count == 1)
        #expect(appliedRanges.first?.start == nil)
        #expect(appliedRanges.first?.end == nil)
    }

    @Test func commit_with_unparseable_text_does_not_apply() {
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
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
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
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
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
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

    @Test func commit_with_empty_text_does_not_apply() {
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
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

    @Test func commit_time_range_emits_single_batched_update() {
        let item = PlaylistItem(url: URL(fileURLWithPath: "/tmp/sample.mov"))
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
