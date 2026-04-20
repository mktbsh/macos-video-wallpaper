// Tests/VideoWallpaperTests/TimeSlotTests.swift
import Foundation
import Testing
@testable import VideoWallpaper

@Suite struct TimeSlotTests {

    @Test func allCases_has_three_elements() {
        #expect(TimeSlot.allCases.count == 3)
    }

    @Test func rawValues_are_stable() {
        #expect(TimeSlot.morning.rawValue == "morning")
        #expect(TimeSlot.afternoon.rawValue == "afternoon")
        #expect(TimeSlot.night.rawValue == "night")
    }

    @Test func codable_roundtrip() throws {
        for slot in TimeSlot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(TimeSlot.self, from: data)
            #expect(decoded == slot)
        }
    }
}
