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
