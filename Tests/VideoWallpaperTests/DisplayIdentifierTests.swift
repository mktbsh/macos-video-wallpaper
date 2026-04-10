import Foundation
import Testing
@testable import VideoWallpaper

struct DisplayIdentifierTests {

    // MARK: - Initialization

    @Test func init_with_values_stores_properties() {
        let id = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        #expect(id.vendor == 1552)
        #expect(id.model == 16418)
        #expect(id.serial == 0)
    }

    // MARK: - CustomStringConvertible

    @Test func description_format_is_vendor_model_serial() {
        let id = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        #expect(id.description == "1552_16418_0")
    }

    @Test func description_with_large_values() {
        let id = DisplayIdentifier(vendor: UInt32.max, model: UInt32.max, serial: UInt32.max)
        #expect(id.description == "\(UInt32.max)_\(UInt32.max)_\(UInt32.max)")
    }

    // MARK: - Hashable

    @Test func equal_identifiers_are_hashable_equal() {
        let lhs = DisplayIdentifier(vendor: 100, model: 200, serial: 300)
        let rhs = DisplayIdentifier(vendor: 100, model: 200, serial: 300)
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test func different_identifiers_are_not_equal() {
        let lhs = DisplayIdentifier(vendor: 100, model: 200, serial: 300)
        let rhs = DisplayIdentifier(vendor: 100, model: 200, serial: 301)
        #expect(lhs != rhs)
    }

    @Test func usable_as_dictionary_key() {
        let id1 = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let id2 = DisplayIdentifier(vendor: 4, model: 5, serial: 6)
        var dict: [DisplayIdentifier: String] = [:]
        dict[id1] = "primary"
        dict[id2] = "secondary"
        #expect(dict[id1] == "primary")
        #expect(dict[id2] == "secondary")
    }

    @Test func usable_in_set() {
        let id = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let duplicate = DisplayIdentifier(vendor: 1, model: 2, serial: 3)
        let set: Set<DisplayIdentifier> = [id, duplicate]
        #expect(set.count == 1)
    }

    // MARK: - userDefaultsKey

    @Test func userDefaultsKey_format_is_prefix_display_description() {
        let id = DisplayIdentifier(vendor: 1552, model: 16418, serial: 0)
        #expect(id.userDefaultsKey(for: "videoBookmark") == "videoBookmark_display_1552_16418_0")
    }

    @Test func userDefaultsKey_with_different_prefix() {
        let id = DisplayIdentifier(vendor: 10, model: 20, serial: 30)
        #expect(id.userDefaultsKey(for: "dimLevel") == "dimLevel_display_10_20_30")
    }

    // MARK: - NSScreen extension

    @Test func mainScreen_displayIdentifier_is_not_nil() {
        guard let screen = NSScreen.main else { return }
        #expect(screen.displayIdentifier != nil)
    }
}
